using Agents:DataFrames, isempty, all_pairs!
using CSV
using Plots
using Agents
using InteractiveDynamics
using Genie
using JSON
using HDF5
using Test
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
	infection_status::Symbol
	infection_detected::Bool
	social_distancing::Float64
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

function model_props()::Dict
	# Create model properties as a dictionary

	loc_width = 2.0
	loc_height = 2.0
	infection_radius = 0.4
	unit_interpolation = 2
	day_steps = 24

	# Create locations
	location_map = [
		[:o :h :h :o :o]
		[:+ :o :o :o :o]
		[:h :o :h :o :h]
		[:o :o :o :o :o]
		[:h :h :o :h :o]
		[:h :o :o :h :o]
	]
	location_info = Dict(   :o => (name = "Empty", capacity = 50), 
							:h => (name = "House", capacity = 10), 
							:+ => (name = "Hospital", capacity = 100)
						)
	Locations = init_locations(location_map, location_info, loc_width, loc_height)
	height, width = size(location_map)

	return Dict(:day => 0, 
				:step => 0,
				:interaction_radius => infection_radius,
				:location_map => location_map, 
				:Locations => Locations,
				:loc_xmin => min([l.x_min for l in Locations]...),
				:loc_xmax => max([l.x_max for l in Locations]...),
				:loc_ymin => min([l.y_min for l in Locations]...),
				:loc_ymax => max([l.y_max for l in Locations]...),
				:loc_height => loc_height,
				:loc_width => loc_width,
				:unit_interpolation => unit_interpolation,
				:day_steps => day_steps,
				:loc_ind_to_id => (ind) -> ((ind[1] - 1) * width + ind[2]),
				:loc_id_to_ind => (id) -> (cld(id, width), ((id - 1) % width) + 1),
				:is_valid_loc_ind => (ind) -> (1 <= ind[1] <= height && 1 <= ind[2] <= width),
				:lockdown => 0.1
			)
end

function get_all_paths_helper(model::ABM, source_ind::NTuple{2,Int64}, dest_ind::NTuple{2,Int64}, visited::Matrix{Bool}, path::Array{Int64}, all_paths::Vector{Vector{Int64}})
	
	visited[source_ind...] = true
	push!(path, model.loc_ind_to_id(source_ind))
	
	if (source_ind == dest_ind)
		push!(all_paths, copy(path))
	else
		left = .+(source_ind, (-1, 0))
		right = .+(source_ind, (1, 0))
		top = .+(source_ind, (0, 1))
		bottom = .+(source_ind, (0, -1))
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
	
	# Get index of start and end locations in location_map
	start_ind = model.loc_id_to_ind(start_loc.id)
	end_ind = model.loc_id_to_ind(end_loc.id)

	path = Vector{Int64}(undef, 0)
	all_paths = Vector{Vector{Int64}}(undef, 0)
	visited = fill(false, size(model.location_map))

	get_all_paths_helper(model, start_ind, end_ind, visited, path, all_paths)
	
	return all_paths

end

function plan_cross_loc_move!(agent::Person, model::ABM, next_loc::Location)
	# Plan journey of `agent` to `next_loc`
	
	if (agent.current_loc_id === next_loc.id)
		return
	end
    
	current_loc = model.Locations[agent.current_loc_id]
	paths = get_travel_path(model, current_loc, next_loc)
	if length(paths) === 0
		return
	end
	path = rand(paths)
	
	old_pos = agent.pos
	for loc_id in path
		loc = model.Locations[loc_id]
		pos = random_in_loc(loc)
		interpolate_steps!(agent, model, old_pos, pos, loc, 2, false)
		old_pos = deepcopy(pos)
	end
	nothing

end

function plan_cross_loc_move!(agent::Person, model::ABM)
	new_loc = rand(model.Locations)
	plan_cross_loc_move!(agent, model, new_loc)
end

function plan_move_home!(agent::Person, model::ABM)
	if (agent.home_loc_id == agent.current_loc_id)
		return
	end
	home = model.Locations[agent.home_loc_id]
	plan_cross_loc_move!(agent, model, home)
end

function plan_same_loc_move!(agent::Person, model::ABM)

	if isempty(agent.upcoming_pos)

		loc = model.Locations[agent.current_loc_id]

		# Add new coordinates for the agent to move in next few steps
		new_pos = random_in_loc(loc)
		
		# interpolate the steps from old->new position
		interpolate_steps!(agent, model, agent.pos, new_pos, loc, 2, true)

	end

end

function move_person!(agent::Person, model::ABM, pos::NTuple{2,Float64})
	loc_ind = location_by_pos(model.Locations, pos)
	if (loc_ind === nothing)
		println("Can't find location for position: ", pos)
	end
	loc = model.Locations[loc_ind]
	move_agent!(agent, pos, model)
	agent.current_loc_id = loc.id
end

function agent_step!(agent::Person, model::ABM)::Nothing

	if (model.step + 5) % model.day_steps === 0 && agent.current_loc_id !== agent.home_loc_id
		empty!(agent.upcoming_pos)
		plan_move_home!(agent, model)
	elseif isempty(agent.upcoming_pos)
		is_probable(0.6) ? plan_same_loc_move!(agent, model) : is_probable(0.5) ? plan_cross_loc_move!(agent, model) : nothing
	end

	if !isempty(agent.upcoming_pos)
		new_pos = popfirst!(agent.upcoming_pos)
		if (new_pos[1] === NaN)
			println("Inside agent step, nan encountered")
		end
		move_person!(agent, model, new_pos)
	end

	social_distancing!(agent, model)

	nothing
end

function social_distancing!(agent::Person, model::ABM)
    nearby = nearby_agents(agent, model, model.interaction_radius)
	if isempty(nearby)
		return
	end

	for neighbor in nearby

		if (neighbor.pos === agent.pos)
			continue
		end

		neighbor_loc = model.Locations[neighbor.current_loc_id]
		
		d = distance(agent.pos, neighbor.pos)
		delta_vec = ((neighbor.pos - agent.pos) / (d^2)) * 0.1
		new_neighbour_pos = clamp_in_loc(neighbor.pos + delta_vec, neighbor_loc)

		move_person!(neighbor, model, new_neighbour_pos)

	end
    
end

function transmit!(a1, a2)
    count(a.infection_status == :I for a in (a1, a2)) ≠ 1 && return
    infected, healthy = a1.infection_status == :I ? (a1, a2) : (a2, a1)
	if is_probable(0.3)
    	healthy.infection_status = :I
	end
    nothing
end

function model_step!(model)
	for (a1, a2) in interacting_pairs(model, model.interaction_radius, :nearest)
        transmit!(a1, a2)
    end
	model.step = model.step + 1
	if model.step % model.day_steps === 0
    	model.day = model.day + 1
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
		add_agent!(pos, model, loc.id, loc.id, [], i in infected ? :I : :S, false, 0.0)
		model.Locations[loc.id].capacity -= 1
	end
	nothing
end

function get_model(num_agents::Int64)::ABM
    
	println("Creating model for ", num_agents, " agents...")    
	space2d = ContinuousSpace((100.0, 100.0), 0.02)
	model = ABM(Person, space2d, properties=model_props())
	init_world(num_agents, model, 5)
	return model
	
end

function main()
	num_agents = 80
	num_iter = 100

	model = get_model(num_agents)
	
	# Run simulation and save agent info
	println("Running x", num_iter, " iterations")
	df_agent, df_model = run!(model, agent_step!, model_step!, num_iter; adata=[:pos, :infection_status, :home_loc_id, :current_loc_id])

	h5open("locations.h5", "w") do file
		write(file, "xmin", map(loc -> loc.x_min, model.Locations))
		write(file, "xmax", map(loc -> loc.x_max, model.Locations))
		write(file, "ymin", map(loc -> loc.y_min, model.Locations))
		write(file, "ymax", map(loc -> loc.y_max, model.Locations))
		write(file, "type", map(loc -> string(loc.type), model.Locations))
	end

    CSV.write("df_agent.csv", df_agent)
    CSV.write("df_model.csv", df_model)

end

function serve()
	route("/get") do

		df_agents = CSV.File(open(read, "df_agent.csv")) |> DataFrames.DataFrame
		xmin = h5open("locations.h5", "r") do file
			read(file, "xmin")
		end
		xmax = h5open("locations.h5", "r") do file
			read(file, "xmax")
		end
		ymin = h5open("locations.h5", "r") do file
			read(file, "ymin")
		end
		ymax = h5open("locations.h5", "r") do file
			read(file, "ymax")
		end
		type = h5open("locations.h5", "r") do file
			read(file, "type")
		end
		locations = [xmin xmax ymin ymax type]
		x_max = max(xmax...)
		y_max = max(ymax...)

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
					"y_max" => y_max)

		JSON.json(data)
	end
	up(8082, async=false)
end

function test()
	num_agents = 80
	model = get_model(num_agents)
	@test true
end

if "test" in ARGS
	test()
elseif "serve" in ARGS
	serve()
elseif "run" in ARGS
	main()
else
	println("Syntax: julia main.jl [test, serve, run]")
end

