using Agents:DataFrames, isempty, all_pairs!, length
using CSV
using Plots
using Agents
using InteractiveDynamics
using Genie
using JSON
using HDF5
using Test
using Dates
using Random
import Base.+, Base.-, Base./, Base.*

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "http://localhost:3000"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

mutable struct Location
	id::Int64
	type::Symbol
	capacity::Int64
	x_min::Float64
	x_max::Float64
	y_min::Float64
	y_max::Float64
end

mutable struct Person <: AbstractAgent
	id::Int64
	pos::NTuple{2,Float64}
	home_loc_id::Int64
	current_loc_id::Int64
	upcoming_pos::Array{NTuple{2,Float64}}
	# infection_status can be :S (susceptible), :IU (infected, undetected), :ID (infected, detected), :+ (Hospitalized), :R (recovered), :D (deceased)
	infection_status::Symbol
	# number of steps in current `infection_status` value
	infection_status_duration::Int64
	social_distancing::Float64
	prob_move_same_loc::Float64
	prob_move_diff_loc::Float64
	hygiene::Float64
end

Ε = 0.1

+(a::NTuple{2,Float64},b::NTuple{2,Float64}) = (a[1]+b[1], a[2]+b[2])
-(a::NTuple{2,Float64},b::NTuple{2,Float64}) = (a[1]-b[1], a[2]-b[2])
/(a::NTuple{2,Float64},b::NTuple{2,Float64}) = (a[1]/b[1], a[2]/b[2])
/(a::NTuple{2,Float64},b::Float64) = (a[1]/b, a[2]/b)
*(a::NTuple{2,Float64},b::Float64) = (a[1]*b, a[2]*b)

is_probable(prob::Float64)::Bool = (rand() < prob)

is_inside_loc(x::Float64, y::Float64, loc::Location)::Bool = (loc.x_min <= x <= loc.x_max && loc.y_min <= y <= loc.y_max)
is_inside_loc(pos::NTuple{2,Float64}, loc::Location)::Bool = is_inside_loc(pos[1], pos[2], loc)

location_ind_by_id(locations::Array{Location}, id::Int64)::NTuple{2,Int64} = (div(id, size(locations)[2]), id % size(locations[2]))
location_by_pos(locations::Array{Location}, pos::NTuple{2,Float64}) = findfirst(loc -> is_inside_loc(pos, loc), locations)

random_in_range(m::Float64, M::Float64, step::Float64=.001)::Float64 = rand(m:step:M)
random_in_loc(loc::Location)::NTuple{2,Float64} = (random_in_range(loc.x_min, loc.x_max), random_in_range(loc.y_min, loc.y_max))

clamp_in_loc(pos::NTuple{2,Float64}, loc::Location)::NTuple{2,Float64} = (clamp(pos[1], loc.x_min + Ε, loc.x_max - Ε), clamp(pos[2], loc.y_min + Ε, loc.y_max - Ε))

interpolate(old::Float64, new::Float64, t::Int64, t0::Int64, tn::Int64)::Float64 = (tn == t0) ? new : (((tn - t) * old + (t - t0) * new) / (tn - t0))

distance(p1::NTuple{2,Float64}, p2::NTuple{2,Float64}) = sqrt((p1[1]-p2[1])^2 + (p1[2]-p2[2])^2)
distance(a1::Person, a2::Person) = distance(a1.pos, a2.pos)

is_infected(a::Person)::Bool = startswith(string(a.infection_status), "I") || a.infection_status == :+
is_detected(a::Person)::Bool = string(a.infection_status) == "ID"

at_location(a::Person, loc_id::Int64)::Bool = a.current_loc_id == loc_id
at_home(a::Person)::Bool = at_location(a, a.home_loc_id)

function init_locations(location_map::Matrix{Symbol}, location_info::Dict, loc_width::Float64, loc_height::Float64)::Array{Location}
	# Create locations array from location map

	locations = []
	id = 1
	rows, cols = size(location_map)
	
	for i = 1:rows
		for j = 1:cols
			type = location_map[i, j]
			capacity = location_info[type].capacity
			loc = Location(id, type, capacity, loc_height * (j - 1), loc_height * j, loc_width * (i - 1), loc_width * i)
			push!(locations, loc)
			id += 1
		end
	end
	
	return locations

end

function interpolate_steps!(agent::Person, model::ABM, old::NTuple{2,Float64}, new::NTuple{2,Float64}, new_loc::Location, n::Int64, do_clamp::Bool)
	oldX, oldY = old
	newX, newY = new
	
	t0 = 1
	tn = n

	for i = t0:tn
		# calculate new interim positions by linear interpolation
		
		interimX = interpolate(oldX, newX, i, t0, tn) + random_in_range(-.1, .1, .001)
		interimY = interpolate(oldY, newY, i, t0, tn) + random_in_range(-.1, .1, .001)
		xy = (interimX, interimY)

		xy = clamp_in_loc(xy, new_loc)

		# push the intermediate step position into upcoming position list of the agent
		push!(agent.upcoming_pos, xy)

	end

end

function get_interpolate_steps(model::ABM, source::NTuple{2,Float64}, destination::NTuple{2,Float64})::Int64
	return 5
	# d = distance(source, destination)
	# if d < eps()
	# 	return 0
	# end
	# return ceil(Int64,d * model.unit_interpolation)
end

function model_props(params::Dict{String, Any})::Dict{Symbol, Any}
	# Create model properties as a dictionary

	loc_width = 2.0
	loc_height = 2.0
	unit_interpolation = 2

	num_houses = params["location"]["num_houses"]
	num_hospitals = params["location"]["num_hospitals"]
	num_empty = params["location"]["num_empty"]

	# Create location map
	# location_map = Random.shuffle(reshape([fill(:h, num_houses);  fill(:+, num_hospitals); fill(:o, num_empty)], Tuple(params["location"]["map_dimensions"])))
	
	# For custom location map creation
	location_map = [
		[:o :h :h :o :o :o]
		[:+ :o :o :o :o :h]
		[:h :o :h :o :h :h]
		[:o :o :o :o :o :o]
		[:h :h :o :h :o :o]
		[:h :o :o :h :+ :h]
	]
	location_map = reverse(location_map, dims=1) # reverse the order so that it looks same while plotting - row becomes +ve y axis, column becomes +ve x axis
	
	location_info = Dict(   :o => (name = "Empty", capacity = 50), 
							:h => (name = "House", capacity = 10), 
							:+ => (name = "Hospital", capacity = 160)
						)
	Locations = init_locations(location_map, location_info, loc_width, loc_height)
	height, width = size(location_map)

	add_param!(dict::Dict, key::String, value::Any) = begin dict[Symbol(key)] = value end

	updated_params = Dict()
	for (key, value) in params
		add_param!(updated_params, key, value)
	end
	add_param!(updated_params, "day", 0)
	add_param!(updated_params, "step", 0)
	add_param!(updated_params, "location_map", location_map)
	add_param!(updated_params, "Locations", Locations)
	add_param!(updated_params, "loc_xmin", min([l.x_min for l in Locations]...))
	add_param!(updated_params, "loc_xmax", max([l.x_max for l in Locations]...))
	add_param!(updated_params, "loc_ymin", min([l.y_min for l in Locations]...))
	add_param!(updated_params, "loc_ymax", max([l.y_max for l in Locations]...))
	add_param!(updated_params, "loc_height", loc_height)
	add_param!(updated_params, "loc_width", loc_width)
	add_param!(updated_params, "unit_interpolation", unit_interpolation)
	add_param!(updated_params, "loc_ind_to_id", (ind) -> ((ind[1] - 1) * width + ind[2]))
	add_param!(updated_params, "loc_id_to_ind", (id) -> (cld(id, width), ((id - 1) % width) + 1))
	add_param!(updated_params, "is_valid_loc_ind", (ind) -> (1 <= ind[1] <= height && 1 <= ind[2] <= width))
	add_param!(updated_params, "lockdown", 0.1)
	add_param!(updated_params, "stop", 0)
	return updated_params

end

function get_all_paths_helper(model::ABM, source_ind::NTuple{2,Int64}, dest_ind::NTuple{2,Int64}, 
							visited::Matrix{Bool}, path::Array{Int64}, all_paths::Vector{Vector{Int64}})
	
	# Recursively get valid path from source to destination and add paths to `all_paths`
	
	visited[source_ind...] = true
	push!(path, model.loc_ind_to_id(source_ind))
	
	if (source_ind == dest_ind)
		# If reached destination, then add to `all_paths`
		push!(all_paths, copy(path))

	else
		# Go to left, right, top and bottom grid locations recursively
		left = (source_ind[1] -1, source_ind[2])
		right = (source_ind[1] +1, source_ind[2])
		top = (source_ind[1], source_ind[2]+1)
		bottom = (source_ind[1], source_ind[2]-1)

		for pos in [left, right, top, bottom]
			if model.is_valid_loc_ind(pos) && !visited[pos...] && (model.location_map[pos...] == :o || pos == dest_ind)
				get_all_paths_helper(model, pos, dest_ind, visited, path, all_paths)
			end
		end

	end

	pop!(path)
	visited[source_ind...] = false
	
end

function get_travel_path(model::ABM, start_loc::Location, end_loc::Location)::Vector{Vector{Int64}}
	# Get a random path from start to end location going through empty locations
	
	# Get index of start and end locations in location_map i.e. from Int64 to (Int64, Int64)
	start_ind = model.loc_id_to_ind(start_loc.id)
	end_ind = model.loc_id_to_ind(end_loc.id)

	# Variable to store current path; initialize with 0s
	path = Vector{Int64}(undef, 0)

	# Variable to store list of all paths
	all_paths = Vector{Vector{Int64}}(undef, 0)
	
	# Boolean matrix to set which locations are already visited when calculating a particular path
	visited = fill(false, size(model.location_map))

	# Get all paths from start_loc to end_loc
	get_all_paths_helper(model, start_ind, end_ind, visited, path, all_paths)

	return all_paths

end

function plan_cross_loc_move!(agent::Person, model::ABM, next_loc::Location)::Bool
	# Plan journey of `agent` to `next_loc`
	
	if at_location(agent, next_loc.id)
		# If agent is already at the destination location, then return
		return false
	end
    
	current_loc = model.Locations[agent.current_loc_id]
	
	# Get all possible paths from current location to next location
	paths = get_travel_path(model, current_loc, next_loc)
	if length(paths) === 0
		# If no possible path exists, then return
		return false
	end

	# Select a random path from list of possible paths
	path = rand(paths)
	
	old_pos = agent.pos
	for loc_id in path

		# Find random position inside location of the path
		loc = model.Locations[loc_id]
		pos = random_in_loc(loc)

		# Interpolate travel to this position from old position
		interpolate_steps!(agent, model, old_pos, pos, loc, 2, false)

		# Update old position
		old_pos = deepcopy(pos)

	end

	return true

end

function plan_cross_loc_move!(agent::Person, model::ABM)

	new_loc = rand(model.Locations)
	plan_cross_loc_move!(agent, model, new_loc)

end

function plan_move_home!(agent::Person, model::ABM)
	# Plan visit to home

	if at_home(agent)
		return
	end

	home = model.Locations[agent.home_loc_id]
	plan_cross_loc_move!(agent, model, home)

end

function plan_move_hospital!(agent::Person, model::ABM)::Bool
	# Plan visit to hospital. Drops current path and go to a random hospital location

	hospitals = filter(loc::Location -> loc.type == :+ && loc.capacity > 0, model.Locations)

	if !isempty(hospitals)
		hospital = rand(hospitals)
		empty!(agent.upcoming_pos)
		return plan_cross_loc_move!(agent, model, hospital)
	end

	return false

end

function plan_same_loc_move!(agent::Person, model::ABM)
	# Move agent within current location

	if isempty(agent.upcoming_pos)

		loc = model.Locations[agent.current_loc_id]

		# Add new coordinates for the agent to move in next few steps
		new_pos = random_in_loc(loc)
		
		# interpolate the steps from old->new position
		interpolate_steps!(agent, model, agent.pos, new_pos, loc, 2, true)

	end

end

function move_person!(agent::Person, model::ABM, pos::NTuple{2,Float64})::Bool
	# Move an agent::Person to new location and update fields accordingly

	# Get old/current location
	old_loc = model.Locations[agent.current_loc_id]

	# Get new location
	new_loc_id = location_by_pos(model.Locations, pos)
	if (new_loc_id === nothing)
		println("Can't find location for position: ", pos)
		return false
	end
	new_loc = model.Locations[new_loc_id]

	# Move agent to new location
	move_agent!(agent, pos, model)
	agent.current_loc_id = new_loc_id

	new_loc.capacity -= 1
	old_loc.capacity += 1

	if new_loc.type == :+ && isempty(agent.upcoming_pos) && is_infected(agent)
		# Hospitalize agent
		agent.prob_move_diff_loc = 0.0 # No going out
		# agent.social_distancing = model.social_distancing[string(new_loc.type)]
		change_infection_status!(agent, :+)
	end

	return true

end

function move_person!(agent::Person, model::ABM)

	if !isempty(agent.upcoming_pos)
		new_pos = popfirst!(agent.upcoming_pos)
		if (new_pos[1] === NaN)
			println("Inside agent step, nan encountered")
		end
		move_person!(agent, model, new_pos)
	end

end

function move_person!(agent::Person, model::ABM, n::Int64)
	
	for _=1:n
		move_person!(agent, model)
	end

end

function agent_step!(agent::Person, model::ABM)::Nothing

	if model.stop != 0 || agent.infection_status == :D
		return
	end

	going_to_hospital = schedule_hospital_visit!(agent, model)
	is_hospitalized = agent.infection_status == :+

	if (model.step + 5) % model.day_steps === 0 && !at_home(agent) && !is_hospitalized && !going_to_hospital
		# At near the end of the day, return to home unless hospitalized

		empty!(agent.upcoming_pos)
		plan_move_home!(agent, model)

	elseif isempty(agent.upcoming_pos) && !is_hospitalized

		if is_probable(agent.prob_move_same_loc)
			plan_same_loc_move!(agent, model)
		elseif is_probable(agent.prob_move_diff_loc)
			plan_cross_loc_move!(agent, model)
		end
		
	end

	move_person!(agent, model)

	# social_distancing!(agent, model)

	prob_detect = model.probabilities["prob_detect"]
	if agent.infection_status == :IU && is_probable(prob_detect[clamp(div(agent.infection_status_duration, model.day_steps), 1, length(prob_detect))])
		change_infection_status!(agent, :ID)
	else
		agent.infection_status_duration += 1
	end

	agent.prob_move_diff_loc = model.probabilities[string(agent.infection_status)]

	handle_location_dynamics!(agent, model)

end

function schedule_hospital_visit!(agent::Person, model::ABM)::Bool

	is_agent_infected = is_infected(agent)
	is_agent_at_hospital = agent.infection_status == :+
	is_agent_going_to_hospital = !isempty(agent.upcoming_pos) && model.Locations[location_by_pos(model.Locations, last(agent.upcoming_pos))].type == :+

	if is_agent_infected && !is_agent_at_hospital && !is_agent_going_to_hospital && is_probable(0.4)
		return plan_move_hospital!(agent, model)
	end

	return false
end

function handle_location_dynamics!(agent::Person, model::ABM)
	
	loc = model.Locations[agent.current_loc_id]

	if agent.infection_status == :+ && loc.type == :+
		# if agent is at the hospital
		
		if (2 * model.day_steps) < agent.infection_status_duration < (7 * model.day_steps) && is_probable(0.2)
			change_infection_status!(agent, :S)
			plan_move_home!(agent, model)
			move_person!(agent, model, 3)

		elseif agent.infection_status_duration >= (7 * model.day_steps) && is_probable(0.2)
			change_infection_status!(agent, :D)

		end

	end

end

function change_infection_status!(agent::Person, status::Symbol)
	if agent.infection_status != status

		agent.infection_status = status
		agent.infection_status_duration = 0

		if agent.infection_status == :D
			# Agent is deceased :(
			agent.prob_move_same_loc = 0.0
			agent.prob_move_diff_loc = 0.0
			empty!(agent.upcoming_pos)
			model.Locations[agent.current_loc_id].capacity += 1
		end

	end
end

function social_distancing!(agent::Person, model::ABM)
    nearby = nearby_agents(agent, model, model.infection_radius)
	if isempty(nearby)
		return
	end

	for neighbor in nearby

		if (neighbor.pos === agent.pos)
			continue
		end

		neighbor_loc = model.Locations[neighbor.current_loc_id]
		
		d = distance(agent.pos, neighbor.pos)
		delta_vec = ((neighbor.pos - agent.pos) / (d^2)) * agent.social_distancing
		new_neighbour_pos = clamp_in_loc(neighbor.pos + delta_vec, neighbor_loc)

		move_person!(neighbor, model, new_neighbour_pos)

	end
    
end

function can_interact(locations::Array{Location}, a1::Person, a2::Person)::Bool
	if at_location(a1, a2.current_loc_id)
		return true
	end
	if locations[a1.current_loc_id].type == locations[a2.current_loc_id].type == :o
		return true
	end
	return false
end

function get_prob_of_spread(a1::Person, a2::Person, model::ABM)::Float64
	# Get probability that infection will spread between two agents where 1 is supposed to be infected
	# This probability is proportional to both agent's hygiene as well as inversely proportional to the distance betwee them

	d = distance(a1, a2)
	if d == 0.0
		return 1.0
	end
	return clamp((1.0 - a1.hygiene) * (1.0 - a2.hygiene) / d, 0.15, 1.0)
	
end

function transmit!(model::ABM, a1::Person, a2::Person)
	count(is_infected(a) for a in (a1, a2)) != 1 && return
	if (a1.infection_status == :D || a2.infection_status == :D)
		return
	end
	
    infected, healthy = is_infected(a1) ? (a1, a2) : (a2, a1)
	if is_probable(get_prob_of_spread(infected, healthy, model)) && can_interact(model.Locations, a1, a2)
		change_infection_status!(healthy, :IU)
	end
    nothing
end

function model_step!(model)

	if model.stop != 0
		return
	end

	for (a1, a2) in interacting_pairs(model, model.infection_radius, :nearest)
        transmit!(model, a1, a2)
    end
	
	model.step = model.step + 1
	if model.step % model.day_steps === 0
    	model.day = model.day + 1
	end

	infected_count = count(is_infected(agent) for (_, agent) in model.agents)
	if infected_count == 0
		println("Stopping early as infection spread stopped at step #", model.step)
		model.stop = model.step
	end

end

function init_world(n::Int64, model::ABM, initial_infections::Int64=1)
	# initialize `n` agents in the model
	infected = rand(1:n, initial_infections)
	for i = 1:n
		available_houses = filter(l -> l.type === :h && l.capacity > 0, model.Locations)
		if isempty(available_houses)
			println("WARN: No house available from agent no. ", i)
			return
		end
		loc = rand(available_houses)
		pos = random_in_loc(loc)
		# add agent into the model
		add_agent!(pos, model, loc.id, loc.id, [], i in infected ? :IU : :S, 0, 0.0, 0.8, 0.5, rand())
		model.Locations[loc.id].capacity -= 1
	end
	nothing
end

function get_model(params::Dict{String, Any})::ABM
    
	println("Creating model for ", params["num_agents"], " agents...")    
	space2d = ContinuousSpace((100.0, 100.0), 0.02)
	model = ABM(Person, space2d, properties=model_props(params))
	init_world(params["num_agents"], model, 5)
	return model
	
end

function model_stats(model::ABM)::Array{Float64}
	susc = 0
	inf_undetected = 0
	inf_detected = 0
	hospitalized = 0
	recovered = 0
	deceased = 0
	for (_, a) in model.agents
		if a.infection_status == :S
			susc += 1
		elseif a.infection_status == :IU
			inf_undetected += 1
		elseif a.infection_status == :ID
			inf_detected += 1
		elseif a.infection_status == :+
			hospitalized += 1
		elseif a.infection_status == :R
			recovered += 1
		elseif a.infection_status == :D
			deceased += 1
		end
	end
	return [susc, inf_undetected, inf_detected, hospitalized, recovered, deceased]
end

function main()
	println("Started at ", Dates.format(now(), "HH:MM:SS"))
	params = get_model_params()
	num_iter = params["num_days"] * params["day_steps"]

	model = get_model(params)
	
	# Run simulation and save agent info
	println("Running x", num_iter, " iterations...")
	df_agent, df_model = run!(model, agent_step!, model_step!, num_iter; adata=[:pos, :infection_status, :home_loc_id, :current_loc_id], mdata=[model_stats])

	if model.stop == 0
		model.stop = model.step
	end

	h5open("model.h5", "w") do file
		write(file, "xmin", map(loc -> loc.x_min, model.Locations))
		write(file, "xmax", map(loc -> loc.x_max, model.Locations))
		write(file, "ymin", map(loc -> loc.y_min, model.Locations))
		write(file, "ymax", map(loc -> loc.y_max, model.Locations))
		write(file, "type", map(loc -> string(loc.type), model.Locations))
		write(file, "stop", model.stop)
	end

    CSV.write("df_agent.csv", df_agent)
    CSV.write("df_model.csv", df_model)

	println("Ended at ", Dates.format(now(), "HH:MM:SS"))

end

function serve()
	println("Serving now...")
	route("/get") do

		df_agents = CSV.File(open(read, "df_agent.csv")) |> DataFrames.DataFrame
		df_model = CSV.File(open(read, "df_model.csv")) |> DataFrames.DataFrame
		xmin = h5open("model.h5", "r") do file
			read(file, "xmin")
		end
		xmax = h5open("model.h5", "r") do file
			read(file, "xmax")
		end
		ymin = h5open("model.h5", "r") do file
			read(file, "ymin")
		end
		ymax = h5open("model.h5", "r") do file
			read(file, "ymax")
		end
		type = h5open("model.h5", "r") do file
			read(file, "type")
		end
		stop = h5open("model.h5", "r") do file
			read(file, "stop")
		end
		locations = [xmin xmax ymin ymax type]
		x_max = max(xmax...)
		y_max = max(ymax...)

		model_stats = eval.(Meta.parse.(df_model.model_stats))
		num_agents = length(unique(df_agents.id))
		step = df_agents.step
		pos = eval.(Meta.parse.(df_agents.pos))
		infection_status = df_agents.infection_status
		home_loc_ids = df_agents.home_loc_id
		current_loc_ids = df_agents.current_loc_id
		data = Dict("num_agents" => num_agents, 
					"step" => step, 
					"id" => df_agents.id, 
					"infection_status" => infection_status,
					"home_loc_ids" => home_loc_ids,
					"current_loc_ids" => current_loc_ids,
					"pos" => pos, 
					"locations" => locations, 
					"x_max" => x_max, 
					"y_max" => y_max,
					"model_stats" => model_stats,
					"stop" => stop)

		JSON.json(data)
	end
	up(8082, async=false)
end

function test()
	num_agents = 80
	model = get_model(num_agents)
	@test true
end

function get_model_params()
	model_name = ARGS[length(ARGS)]
	params = JSON.parsefile("../models/params.json")[model_name]
	return params
end

if length(ARGS) == 1 && "test" == ARGS[1]
	test()
elseif length(ARGS) == 1 && "serve" == ARGS[1]
	serve()
elseif length(ARGS) == 2 && "run" == ARGS[1]
	main()
elseif length(ARGS) == 3 && "run" == ARGS[1] && "serve" == ARGS[2]
	main()
	serve()
end

