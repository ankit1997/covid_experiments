module ParametersMod

export model_params, 
Parameters, 
Person, 
Location, 
loc_ind2id, 
loc_id2ind, 
EMPTY, 
HOUSE, 
HOSPITAL, 
SUSCEPTIBLE, 
MILD, 
PRESYMPTOMATIC, 
ASYMPTOMATIC, 
INFECTED, 
SEVERE, 
HOSPITALIZED, 
RECOVERED, 
DECEASED,
distance,
is,
is_infected,
is_symptomatic,
at_location,
at_home

using JSON
using Random
using Agents:AbstractAgent,ABM
using ..UtilsMod

_params_cache = Dict{String,Any}()
EMPTY = :O
HOUSE = :H
HOSPITAL = :+

SUSCEPTIBLE = :SUSCEPTIBLE
MILD = :MILD
PRESYMPTOMATIC = :PRESYMPTOMATIC
ASYMPTOMATIC = :ASYMPTOMATIC
INFECTED = :INFECTED
SEVERE = :SEVERE
HOSPITALIZED = :HOSPITALIZED
RECOVERED = :RECOVERED
DECEASED = :DECEASED

mutable struct Location
	id::Int64
	type::Symbol
	capacity::Int64
	x_min::Float64
	x_max::Float64
	y_min::Float64
	y_max::Float64
    social_distancing::Float64
    prob_move_in_same_loc::Float64
    prob_move_to_diff_loc::Float64
    prob_come_from_diff_loc::Float64
end

mutable struct Person <: AbstractAgent
	id::Int64
	pos::NTuple{2,Float64}
	home_loc_id::Int64
	current_loc_id::Int64
	upcoming_pos::Array{NTuple{2,Float64}}
	infection_status::Symbol
	infection_status_duration::Int64
	is_masked::Bool
	vaccine_shots::Int64
	prob_get_infected::Float64
	is_asymptomatic::Bool
end

mutable struct Parameters

    name::String

    day::Int64
    step::Int64
    stop_flag::Bool

    num_agents::Int64
    num_days::Int64
    num_steps_in_day::Int64

    infection_radius::Float64
    initial_infections::Int64

    world_width::Float64
    world_height::Float64
    loc_width::Float64
    loc_height::Float64
    Locations::Array{Location}
    map::Matrix{Symbol}
    map_item_capacity::Dict{Symbol,Int64}

    prob_visit_hospital::Dict{Symbol, Float64}

    prob_vaccinated_and_spread::NTuple{2,Float64}
    percentage_masked::Float64

end

function loc_ind2id(ind::NTuple{2,Int64}, p::Parameters)::Int64
    _, columns = size(p.map)
    return (ind[1] - 1) * columns + ind[2]
end

function loc_id2ind(id::Int64, p::Parameters)::NTuple{2,Int64}
    _, columns = size(p.map)
    return (cld(id, columns), ((id - 1) % columns) + 1)
end

function distance(a1::Person, a2::Person)
	distance(a1.pos, a2.pos)
end

function is(a::Person, infection_status::Symbol)::Bool
	a.infection_status === infection_status
end

function is(loc::Location, type::Symbol)::Bool
	loc.type === type
end

function is_alive(agent::Person)::Bool
    agent.infection_status !== DECEASED
end

function is_infected(a::Person)::Bool
	is(a, MILD) || is(a, ASYMPTOMATIC) || is(a, INFECTED) || is(a, HOSPITALIZED)
end

function is_symptomatic(a::Person)::Bool
	is(a, INFECTED) || is(a, HOSPITALIZED)
end

function at_location(a::Person, loc_id::Int64)::Bool
    a.current_loc_id === loc_id
end

function at_location(a::Person, loc_type::Symbol, p::Parameters)
	ind = loc_id2ind(a.current_loc_id, p)
	p.map[ind...] === loc_type
end

function at_home(a::Person)::Bool
    at_location(a, a.home_loc_id)
end

function _init_locations(map::Matrix{Symbol}, map_item_capacity::Dict)::Array{Location}

	locations = []
	id = 1
	rows, cols = size(map)
    loc_height = 2.0
    loc_width = 2.0
    
	for i = 1:rows
		for j = 1:cols
			type = map[i, j]
            capacity = map_item_capacity[type]
            xmin = loc_height * (j - 1)
            xmax = loc_height * j
            ymin = loc_width * (i - 1)
            ymax = loc_width * i

            prob_move_in_same_loc = 0.9
            prob_move_to_diff_loc = 0.8
            prob_come_from_diff_loc = 0.9
            if type == HOSPITAL
                prob_move_in_same_loc = 0.1
                prob_move_to_diff_loc = 0.001
            end

			loc = Location(id, type, capacity, xmin, xmax, ymin, ymax, 0.01, prob_move_in_same_loc, prob_move_to_diff_loc, prob_come_from_diff_loc)
            push!(locations, loc)
			id += 1
		end
	end
    	
	return locations

end

function _read_params(model_name::String, params::Dict)::Parameters
    
    map_item_capacity = Dict()
    for (loc_type, capacity) in params["location"]["capacity"]
        map_item_capacity[Symbol(loc_type)] = capacity
    end

    # Create location map
    num_houses = params["location"]["num_houses"]
    num_hospitals = params["location"]["num_hospitals"]
    num_empty = params["location"]["num_empty"]
	location_map = Random.shuffle(reshape([fill(HOUSE, num_houses);  fill(HOSPITAL, num_hospitals); fill(EMPTY, num_empty)], Tuple(params["location"]["map_dimensions"])))
	# For custom location map creation
	# location_map = [
	# 	[EMPTY      HOUSE       HOUSE       EMPTY       EMPTY       EMPTY]
	# 	[HOSPITAL   EMPTY       EMPTY       EMPTY       EMPTY       HOUSE]
	# 	[HOUSE      EMPTY       HOUSE       EMPTY       HOUSE       HOUSE]
	# 	[EMPTY      EMPTY       EMPTY       EMPTY       EMPTY       EMPTY]
	# 	[HOUSE      HOUSE       EMPTY       HOUSE       EMPTY       EMPTY]
	# 	[HOUSE      EMPTY       EMPTY       HOUSE       HOSPITAL    HOUSE]
	# ]
	# location_map = reverse(location_map, dims=1) # reverse the order so that it looks same while plotting - row becomes +ve y axis, column becomes +ve x axis
    locations = _init_locations(location_map, map_item_capacity)

    prob_visit_hospital = Dict()
    prob_visit_hospital[:SUSCEPTIBLE] = 0.01
    prob_visit_hospital[:MILD] = 0.2
    prob_visit_hospital[:PRESYMPTOMATIC] = 0.01
    prob_visit_hospital[:ASYMPTOMATIC] = 0.01
    prob_visit_hospital[:INFECTED] = 0.4
    prob_visit_hospital[:SEVERE] = 0.8
    prob_visit_hospital[:HOSPITALIZED] = 0.0
    prob_visit_hospital[:RECOVERED] = 0.01
    prob_visit_hospital[:DECEASED] = 0.0

    parameters = Parameters(model_name, 0, 0, false, params["num_agents"], params["num_days"], params["num_steps_in_day"], params["infection_radius"], 
                            params["initial_infections"], 100.0, 100.0, 2.0, 2.0, locations, location_map, map_item_capacity, prob_visit_hospital, (0.6, 0.2), params["percentage_masked"])
    _params_cache[model_name] = parameters

    return _params_cache[model_name]

end

function enrich_params!(model::ABM, attrs::Dict)
    parameters = model.parameters
    parameters.infection_radius = get(attrs, "infection_radius", parameters.infection_radius)
    # parameters.prob_visit_hospital = get(attrs, "prob_visit_hospital", parameters.prob_visit_hospital)
    parameters.prob_vaccinated_and_spread = get(attrs, "prob_vaccinated_and_spread", Tuple(parameters.prob_vaccinated_and_spread))
    

    percentage_masked = get(attrs, "percentage_masked", 0.1)
    if parameters.percentage_masked !== percentage_masked
        
        masked_agents = [agent.id for (_, agent::Person) in model.agents if agent.is_masked && is_alive(agent)]
        num_of_masked_new = clamp(ceil(Int64, (percentage_masked / 100.0) * parameters.num_agents), 1, length(model.agents))

        if length(masked_agents) > num_of_masked_new
            # if percentage of masked people has decreased, unmask already masked agents
            diff = length(masked_agents) - num_of_masked_new
            remove_mask = rand(masked_agents, diff)
            for id in remove_mask
                model.agents[id].is_masked = false
            end
        elseif length(masked_agents) < num_of_masked_new
            # if percentage of masked people has increased, mask new agents who are not masked
            diff = num_of_masked_new - length(masked_agents)
            unmasked_agents = rand([agent.id for (_, agent::Person) in model.agents if !agent.is_masked && is_alive(agent)], diff)
            for id in unmasked_agents
                model.agents[id].is_masked = true
            end
        end

    end

end

function model_params(model_name::String, params::Dict)::Parameters
    return _read_params(model_name, params)
end

end