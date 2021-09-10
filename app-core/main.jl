include("utilities/Common_utils.jl")
include("entities/Person.jl")
include("entities/Location.jl")
include("entities/Parameters.jl")

include("utilities/Model_utils.jl")
include("utilities/Location_utils.jl")

include("blocks/Social_Distancing.jl")
include("blocks/Transmission.jl")
include("blocks/Move.jl")
include("blocks/Data_Collect.jl")
include("blocks/Initiator.jl")
include("blocks/Updater.jl")

include("steps/model_step.jl")
include("steps/agent_step.jl")

using .CommonUtilsModule
using .LocationModule
using .PersonModule
using .ParametersModule
using .ModelUtilsModule
using .LocationUtilsModule
using .SocialDistancingBlock
using .TransmissionBlock
using .MoveBlock
using .DataCollectBlock
using .InitiatorBlock
using .UpdaterBlock
using .ModelStepModule
using .AgentStepModule

using Genie, Genie.Requests
using JSON
using Serialization
using Agents:ABM,step!

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "http://localhost:4200"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

model_cache = Dict()
update_semaphores = Dict{String,Base.Semaphore}()

function capture_data(model::ABM)::Dict
	data = collector(model)
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

function simulate_steps!(model::ABM, n::Int64=1)
    for i = 1:n
        model.parameters.stop_flag && return
        step!(model, agent_step_basic!, model_step_basic!)
        capture_data(model)
    end
end

function read_old_data(fname::String, step::Int64)
    data = ""
	open(fname, "r") do io
		raw = strip(read(io, String))
		data = split(raw, "\n")[step]
	end
    return data
end

function terminate_model(model_name::String)
	!haskey(update_semaphores, model_name) && return
	Base.acquire(update_semaphores[model_name])
	delete!(model_cache, model_name)
	Base.release(update_semaphores[model_name])
	println("Removed ", model_name, " from cache.")
end

function serialize_model(model::ABM)
	fname = "output/" * model.parameters.name * ".model"
	io = open(fname, "w")
	serialize(io, model)
	close(io)
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

	if haskey(model_cache, model_name)
		return get_response(false, "Model name already exists, use a different name")
    elseif isfile(fname)
        return get_response(false, "Model name already used, please download the data or use a different name")
	else
		local model = get_model(model_name, params)
		model_cache[model_name] = model
	end
	
	update_semaphores[model_name] = Base.Semaphore(1)

	model = model_cache[model_name]
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
		# serialize_model(model_cache[model_name])
		terminate_model(model_name)
		return get_response(true, "Model terminated successfully")
	else
		return get_response(false, "Model not initiated")
	end
end

route("/delete") do
	model_name = params(:model_name)
	if haskey(model_cache, model_name)
		terminate_model(model_name)
	end
	if isfile("output/" * model_name * ".steps")
		rm("output/" * model_name * ".steps")
	end
	if isfile("output/" * model_name * ".updates")
		rm("output/" * model_name * ".updates")
	end
	if isfile("output/" * model_name * ".model")
		rm("output/" * model_name * ".model")
	end
	return get_response(true, "Success")
end

route("/step") do
	model_name = params(:model_name)
    step = parse(Int64, params(:step))

	if !haskey(model_cache, model_name)
		return get_response(false, "Model not initialized")
	end

	model = model_cache[model_name]::ABM

	if model.parameters.stop_flag
		return get_response(false, "END")
	end

    fname = "output/" * model_name * ".steps"
	Base.acquire(update_semaphores[model_name])
    if model.parameters.step > step
        data = read_old_data(fname, step)
        Base.release(update_semaphores[model_name])
        return data
    end
    simulate_steps!(model, model.parameters.step_size)
	response = read_old_data(fname, step)
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

    return read_old_data(fname, step)

end

route("/latestStep") do
	model_name = params(:model_name)
	if !haskey(model_cache, model_name)
		return get_response(false, "Model not initialized")
	end

	model = model_cache[model_name]::ABM
	return JSON.json(Dict("latest_step" => model.parameters.step))
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
    enrich_params!(model, params)
	Base.release(update_semaphores[model_name])

	return get_response(true, "Model updated successfully")

end

route("/migrants/add", method=POST) do

	payload = JSON.parse(rawpayload())
	params = payload["params"]
	model_name = params["model_name"]
	total_migrants = params["migrants"]["count"]
    infection_status = params["migrants"]["infection_status"]

	if !haskey(model_cache, model_name)
		return get_response(false, "Model not initialized")
	end
	model = model_cache[model_name]::ABM

	Base.acquire(update_semaphores[model_name])
    add_extra_agents!(model, total_migrants, infection_status)
	Base.release(update_semaphores[model_name])

	return get_response(true, "Migrants added successfully")

end

route("/data") do
	model_name = params(:model_name)
	start_step = parse(Int64, params(:start, 1))
	end_step = parse(Int64, params(:end, -1))

	fname = "output/" * model_name * ".steps"
    if !isfile(fname)
        return get_response(false, "Data not found")
    end
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