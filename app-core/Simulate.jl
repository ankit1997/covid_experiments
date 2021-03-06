module SimulateMod

include("Utils.jl")
include("Parameters.jl")
include("Locations.jl")
include("Journey.jl")
include("Person.jl")
include("Model.jl")
include("DataCollector.jl")

using Genie, Genie.Requests
using JSON
using Agents:ABM,step!,interacting_pairs
using .PersonMod
using .JourneyMod
using .UtilsMod
using .ParametersMod
using .ModelMod
using .LocationMod
using .DataCollectorMod
using Dates

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "http://localhost:4200"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

model_cache = Dict()
update_semaphores = Dict{String,Base.Semaphore}()

function agent_step!(agent::Person, model::ABM)

	if is(agent, DECEASED)
		return
	end

	params = model.parameters

	going_to_hospital = false
	is_hospitalized = is(agent, HOSPITALIZED)
	if is_probable(model.parameters.prob_visit_hospital[agent.infection_status]) && !is_hospitalized && model.parameters.step % model.parameters.num_steps_in_day === 0
		going_to_hospital = JourneyMod.schedule_hospital_visit!(agent, model)
	end

	at_home = agent.home_loc_id === LocationMod.location_by_pos(agent.pos, params).id

	if (params.step + 5) % params.num_steps_in_day === 0 && !at_home && !is_hospitalized && !going_to_hospital
		# At near the end of the day, return to home unless hospitalized

		JourneyMod.plan_move_home!(agent, model)

	elseif isempty(agent.upcoming_pos) && !is_hospitalized

		current_loc_id = LocationMod.location_by_pos(agent.pos, params).id
		local_move_prob = params.Locations[current_loc_id].prob_move_in_same_loc
		outside_move_prob = params.Locations[current_loc_id].prob_move_to_diff_loc

		if is_probable(local_move_prob * PersonMod.get_move_prob(agent))
			# roam around in same location
			JourneyMod.plan_same_loc_move!(agent, model)
		elseif is_probable(outside_move_prob * PersonMod.get_move_prob(agent))
			# go to different location
			JourneyMod.plan_cross_loc_move!(agent, model)
		end
		
	end

	PersonMod.move_person!(agent, model)

	PersonMod.infection_dynamics!(agent, model)

	model.agents_processed += 1
	
end

function model_step!(model::ABM)

	ModelMod.social_distancing!(model)

	for (a1, a2) in interacting_pairs(model, model.parameters.infection_radius, :nearest)
		PersonMod.transmit!(a1, a2, model)
    end
	
	model.parameters.step = model.parameters.step + 1
	if (model.parameters.step % model.parameters.num_steps_in_day) === 0
    	model.parameters.day = model.parameters.day + 1
	end

	infected_count = count(is_infected(agent) for (_, agent) in model.agents)
	if infected_count == 0
		model.parameters.stop_flag = true
	end

end

function capture_data(model::ABM)::Dict
	data = DataCollectorMod.capture(model)

	fname = "output/" * model.parameters.name * ".steps"
	if !isfile(fname)
		if !isdir("output")
			mkdir("output")
		end
		touch(fname)
	end
	open(fname, "a") do io
		write(io, JSON.json(data) * "\n")
	end

	return data
end

function simulate_step!(model::ABM)
	if model.parameters.stop_flag
		return
	end
	step!(model, agent_step!, model_step!)
	return capture_data(model)
end

function simulate_steps!(model::ABM, n::Int64)
	data = Dict()
	for _ = 1:n
		data = simulate_step!(model)
	end
	return data
end

function get_response(success::Bool, message::String)
	return JSON.json(Dict("success" => success, "message" => message))
end

route("/") do
	return "Welcome to Covid Simulator"
end

route("/init", method=POST) do
	# Initialize the model based on input parameters
	
	payload = JSON.parse(rawpayload())
	params = payload["params"]
	model_name = params["model_name"]
	fname = "output/" * model_name * ".steps"

	if haskey(model_cache, model_name) || isfile(fname)
		return get_response(false, "Model name already exists, use a different name")
	else
		local model = ModelMod.get_model(model_name, params)
		model_cache[model_name] = model
	end
	
	update_semaphores[model_name] = Base.Semaphore(1)

	model = model_cache[model_name]
	println("Models in cache: ", collect(keys(model_cache)))
	display(model.parameters.map)
	println("")
	return get_response(true, "Model initialized successfully")
end

route("/map") do
	
	model_name = params(:model_name)

	if !haskey(model_cache, model_name)
		return get_response(false, "Model not initialized")
	end
	
	model = model_cache[model_name]::ABM

	return JSON.json(map(loc -> begin
		Dict(string(k) => getfield(loc, k) for k in fieldnames(Location))
    end, model.parameters.Locations))

end

route("/terminate") do
	model_name = params(:model_name, "")
	if haskey(model_cache, model_name)
		Base.acquire(update_semaphores[model_name])
		delete!(model_cache, model_name)
		Base.release(update_semaphores[model_name])
		println("Removed ", model_name, " from cache.")
		println("Models in cache: ", collect(keys(model_cache)))
		return get_response(true, "Model terminated successfully")
	else
		return get_response(false, "Model not initiated")
	end
end

route("/step") do
	model_name = params(:model_name)

	if !haskey(model_cache, model_name)
		return get_response(false, "Model not initialized")
	end

	model = model_cache[model_name]::ABM

	if model.parameters.stop_flag
		return get_response(false, "END")
	end

	Base.acquire(update_semaphores[model_name])
	model.agents_processed = 0
	response = JSON.json(simulate_steps!(model, model.parameters.step_size))
	println("model.agents_processed = ", model.agents_processed)
	Base.release(update_semaphores[model_name])

	return response

end

route("/oldData") do
	model_name = params(:model_name)
	step = parse(Int64, params(:step))

	fname = "output/" * model_name * ".steps"
	if !isfile(fname)
		return get_response(false, "Step data not found")
	end

	data = Dict()
	open(fname, "r") do io
		raw = strip(read(io, String))
		data = split(raw, "\n")[step]
	end

	return data

end

route("/update", method=POST) do

	payload = JSON.parse(rawpayload())
	params = payload["params"]
	model_name = params["model_name"]

	if !haskey(model_cache, model_name)
		return get_response(false, "Model not initialized")
	end
	model = model_cache[model_name]::ABM

	Base.acquire(update_semaphores[model_name])
	ParametersMod.enrich_params!(model, params)
	Base.release(update_semaphores[model_name])

	return get_response(true, "Model updated successfully")

end

route("/migrants/add", method=POST) do

	payload = JSON.parse(rawpayload())
	params = payload["params"]
	model_name = params["model_name"]
	total_migrants = params["migrants"]["count"]

	if !haskey(model_cache, model_name)
		return get_response(false, "Model not initialized")
	end
	model = model_cache[model_name]::ABM

	Base.acquire(update_semaphores[model_name])
	ModelMod._add_agents!(model, total_migrants)
	Base.release(update_semaphores[model_name])

	return get_response(true, "Migrants added successfully")

end

route("/data") do
	model_name = params(:model_name)
	start_step = parse(Int64, params(:start, 1))
	end_step = parse(Int64, params(:end, -1))

	fname = "output/" * model_name * ".steps"
	data = []
	open(fname, "r") do io
		raw = strip(read(io, String))
		jsons = split(raw, "\n")
		end_step = end_step == -1 ? length(jsons) : end_step
		for i = start_step:end_step
			try
				push!(data, JSON.parse(jsons[i]))
			catch e
				println("Failed JSON.parse at ", i)
			end
		end
	end

	return JSON.json(data)
	
end

up(8082, async=false)

end