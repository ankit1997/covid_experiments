using Agents:DataFrames, isempty, all_pairs!
using CSV
using Plots
using Agents
using InteractiveDynamics
using Genie
using JSON
using HDF5

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

Ε = eps()

is_probable(prob::Float64)::Bool = (rand() < prob)

is_inside_loc(x::Float64, y::Float64, loc::Location)::Bool = (loc.x_min <= x <= loc.x_max && loc.y_min <= y <= loc.y_max)
is_inside_loc(pos::NTuple{2,Float64}, loc::Location)::Bool = is_inside_loc(pos[1], pos[2], loc)

location_ind_by_id(locations::Array{Location}, id::Int64)::NTuple{2,Int64} = (div(id, size(locations)[2]), id % size(locations[2]))
location_by_pos(locations::Array{Location}, pos::NTuple{2,Float64}) = findfirst(loc -> is_inside_loc(pos, loc), locations)

random_in_range(m::Float64, M::Float64, step::Float64=.001)::Float64 = rand(m:step:M)
random_in_loc(loc::Location)::NTuple{2,Float64} = (random_in_range(loc.x_min, loc.x_max), random_in_range(loc.y_min, loc.y_max))

clamp_in_loc(pos::NTuple{2,Float64}, loc::Location)::NTuple{2,Float64} = (clamp(pos[1], loc.x_min + Ε, loc.x_max - Ε), clamp(pos[2], loc.y_min + Ε, loc.y_max - Ε))

interpolate(old::Float64, new::Float64, t::Int64, t0::Int64, tn::Int64)::Float64 = (tn == t0) ? new : (((tn - t) * old + (t - t0) * new) / (tn - t0))


function calculate_current_loc(agent::Person, locations::Array{Location})
	agent.current_loc_id = location_by_pos(locations, agent.pos)
end

function Paths(location_map::Matrix{Symbol}, locations::Array{Location})
	function find_all_paths_helper(source::NTuple{2,Int64}, dest::NTuple{2,Int64}, visited::Matrix{Bool}, path::Array{NTuple{2,Int64}}, paths::Array{Int64})
		visited[source[1], source[2]] = true
		push!(path, )
	end
	function find_all_paths(source_id::Int64, dest_id::Int64)
		source_i, source_j = location_pos_by_id(locations, source_id)
		dest_i, dest_j = location_pos_by_id(locations, dest_id)
		
	end
	() -> (find_all_paths,)
end

function get_all_possible_paths(location_map::Matrix{Symbol}, source_id::Int64, dest_id::Int64)
	
end

function init_locations(location_map::Matrix{Symbol}, location_info::Dict, row_size::Float64=5.0, col_size::Float64=5.0)::Array{Location}
	# Create locations array from location map
	locations = []
	id = 1
	rows, cols = size(location_map)
	for i = 1:rows
		for j = 1:cols
			type = location_map[i, j]
			capacity = location_info[type].capacity
			loc = Location(id, type, capacity, col_size * (j - 1), col_size * j, row_size * (i - 1), row_size * i)
			push!(locations, loc)
			id += 1
		end
	end
	return locations
end

function interpolate_steps(agent::Person, model::ABM, old::NTuple{2,Float64}, new::NTuple{2,Float64}, n::Int64)
	oldX, oldY = old
	newX, newY = new
	t0 = 1
	tn = n
	for i = t0:tn
		# calculate new interim positions by linear interpolation
		interimX = interpolate(oldX, newX, i, t0, tn) + random_in_range(-1., 1., .001)
		interimY = interpolate(oldY, newY, i, t0, tn) + random_in_range(-1., 1., .001)
		
		# clamp coordinates to within the current location
		xy = clamp_in_loc((interimX, interimY), model.Locations[agent.current_loc_id])

		# push the intermediate step position into upcoming position list of the agent
		push!(agent.upcoming_pos, xy)

	end
end

	
function model_props(infection_radius::Float64)::Dict
	# Create model properties as a dictionary

	# Create locations
	location_map = [
		[:o :h :h :o]
		[:+ :o :o :h]
		[:h :o :h :o]
		[:o :o :o :o]
		[:h :h :o :h]
		[:h :o :o :h]
	]
	location_info = Dict(   :o => (name = "Empty", capacity = 50), 
							:h => (name = "House", capacity = 10), 
							:+ => (name = "Hospital", capacity = 100)
						)
	Locations = init_locations(location_map, location_info)
	height, width = size(location_map)

	return Dict(:day => 0.0, 
				:interaction_radius => infection_radius,
				:location_map => location_map, 
				:Locations => Locations,
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
		push!(all_paths, path)
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

function plan_cross_loc_move(agent::Person, model::ABM, next_loc::Location)
	# Plan journey of `agent` to `loc`
	
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
		pos = random_in_loc(model.Locations[loc_id])
		interpolate_steps(agent, model, old_pos, pos, 2)
		old_pos = pos
	end

end

function plan_cross_loc_move(agent::Person, model::ABM)
	new_loc = rand(model.Locations)
	plan_cross_loc_move(agent, model, new_loc)
end

function plan_move_home(agent::Person, model::ABM)
	if (agent.home_loc_id == agent.current_loc_id)
		return
	end
	home = model.Locations[agent.home_loc_id]
	plan_cross_loc_move(agent, model, home)
end


function plan_same_loc_move(agent::Person, model::ABM)

	if isempty(agent.upcoming_pos)

		# Add new coordinates for the agent to move in next few steps
		new_pos = random_in_loc(model.Locations[agent.current_loc_id])
		
		# interpolate the steps from old->new position
		interpolate_steps(agent, model, agent.pos, new_pos, 5)

	end

end
	
function agent_step!(agent::Person, model::ABM)::Nothing

	if isempty(agent.upcoming_pos)
		is_probable(0.6) ? plan_same_loc_move(agent, model) : is_probable(0.5) ? plan_cross_loc_move(agent, model) : nothing
	end

	if !isempty(agent.upcoming_pos)
		new_pos = popfirst!(agent.upcoming_pos)
		move_agent!(agent, new_pos, model)
		calculate_current_loc(agent, model.Locations)
	end

	nothing
end

function social_distancing(agent::Person, model::ABM)
    nearby = nearby_agents(agent, model, model.interaction_radius)
    if !isempty(nearby)
        # move away from nearby agents
        
        
    end
end

function transmit!(a1, a2)
    count(a.infection_status == :I for a in (a1, a2)) ≠ 1 && return
    infected, healthy = a1.infection_status == :I ? (a1, a2) : (a2, a1)
    healthy.infection_status = :I
    nothing
end

function model_step!(model)
	for (a1, a2) in interacting_pairs(model, model.interaction_radius, :nearest)
        transmit!(a1, a2)
    end
    model.day = model.day + 1
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
	model = ABM(Person, space2d, properties=model_props(3.0))
	init_world(num_agents, model, 5)
	return model
	
end

function main()
	num_agents = 80
	num_iter = 50

	model = get_model(num_agents)
	
	# Run simulation and save agent info
	println("Running x", num_iter, " iterations")
	df_agent, df_model = run!(model, agent_step!, model_step!, num_iter; adata=[:pos, :infection_status])

	locations = map(loc -> [loc.x_min, loc.x_max, loc.y_min, loc.y_max], model.Locations)
	h5open("locations.h5", "w") do file
		write(file, "xmin", map(loc -> loc.x_min, model.Locations))
		write(file, "xmax", map(loc -> loc.x_max, model.Locations))
		write(file, "ymin", map(loc -> loc.y_min, model.Locations))
		write(file, "ymax", map(loc -> loc.y_max, model.Locations))
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
		locations = [xmin xmax ymin ymax]
		x_max = max(xmax...)
		y_max = max(ymax...)

		num_agents = length(unique(df_agents.id))
		step = df_agents.step
		pos = eval.(Meta.parse.(df_agents.pos))
		data = Dict("num_agents" => num_agents, "step" => step, "id" => df_agents.id, "pos" => pos, "locations" => locations, "x_max" => x_max, "y_max" => y_max)

		JSON.json(data)
	end
	up(8082, async=false)
end

# main()
serve()

