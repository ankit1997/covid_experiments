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
is_symptomatic

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
    step_size::Int64
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

    prob_visit_hospital::Dict{Symbol,Float64}

    prob_vaccinated_and_spread::NTuple{2,Float64}
    percentage_masked::Float64
    percentage_vaccinated::Array{Float64}

    social_distancing::Int64

end

function loc_ind2id(ind::NTuple{2,Int64}, p::Parameters)::Int64
    ROWS, COLUMNS = size(p.map)
    return (ROWS - ind[1]) * COLUMNS + ind[2]
end

function loc_id2ind(id::Int64, p::Parameters)::NTuple{2,Int64}
    ROWS, COLUMNS = size(p.map)
    r = ROWS - floor(Int64, (id - 1) / COLUMNS)
    c = ((id - 1) % COLUMNS) + 1
    return (r, c)
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

function _init_locations(map::Matrix{Symbol}, map_item_capacity::Dict, loc_width::Float64, loc_height::Float64)::Array{Location}

	locations = []
	id = 1
	rows, cols = size(map)
    
	for i = rows:-1:1
		for j = 1:cols
			type = map[i, j]
            capacity = map_item_capacity[type]

            # calculate bounding box of location
            xmin = loc_width * (j - 1)
            xmax = loc_width * j
            ymin = loc_height * (rows - i)
            ymax = loc_height * (rows - i + 1)

            # probability for movement
            prob_move_in_same_loc = type === HOSPITAL ? 0.001 : 0.9
            prob_move_to_diff_loc = type === HOSPITAL ? 0.001 : 0.9
            prob_come_from_diff_loc = 0.9

            social_distancing = 0.01

			loc = Location(id, type, capacity, xmin, xmax, ymin, ymax, social_distancing, prob_move_in_same_loc, prob_move_to_diff_loc, prob_come_from_diff_loc)
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
    map_dimens = Tuple(params["location"]["map_dimensions"])
    num_houses = params["location"]["num_houses"]
    num_hospitals = params["location"]["num_hospitals"]
    num_empty = map_dimens[1] * map_dimens[2] - (num_houses + num_hospitals)

    loc_width = 2.0
    loc_height = 2.0
    

	location_map = Random.shuffle(reshape([fill(HOUSE, num_houses);  fill(HOSPITAL, num_hospitals); fill(EMPTY, num_empty)], map_dimens))
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
    locations = _init_locations(location_map, map_item_capacity, loc_width, loc_height)

    prob_visit_hospital = Dict()
    prob_visit_hospital[:SUSCEPTIBLE] = 0.0001
    prob_visit_hospital[:MILD] = 0.1
    prob_visit_hospital[:PRESYMPTOMATIC] = 0.01
    prob_visit_hospital[:ASYMPTOMATIC] = 0.001
    prob_visit_hospital[:INFECTED] = 0.4
    prob_visit_hospital[:SEVERE] = 0.8
    prob_visit_hospital[:HOSPITALIZED] = 0.0
    prob_visit_hospital[:RECOVERED] = 0.0001
    prob_visit_hospital[:DECEASED] = 0.0

    prob_vaccinated_and_spread = (0.6, 0.2)

    parameters = Parameters(model_name, 
                            0, 
                            0, 
                            params["step_size"],
                            false, 
                            params["num_agents"], 
                            params["num_days"], 
                            params["num_steps_in_day"], 
                            params["infection_radius"], 
                            params["initial_infections"], 
                            100.0, 100.0, loc_width, loc_height, 
                            locations, 
                            location_map, 
                            map_item_capacity, 
                            prob_visit_hospital, 
                            prob_vaccinated_and_spread, 
                            params["percentage_masked"],
                            params["percentage_vaccinated"],
                            params["social_distancing"])
    _params_cache[model_name] = parameters

    return _params_cache[model_name]

end

function enrich_params!(model::ABM, attrs::Dict)
    parameters = model.parameters
    updated = Dict()

    _update_param_field(model, :infection_radius, attrs["infection_radius"], updated)
    _update_param_field(model, :social_distancing, attrs["social_distancing"], updated)
    _update_param_field(model, :step_size, attrs["step_size"], updated)
    
    # parameters.infection_radius = get(attrs, "infection_radius", parameters.infection_radius)
    # parameters.prob_visit_hospital = get(attrs, "prob_visit_hospital", parameters.prob_visit_hospital)
    # parameters.prob_vaccinated_and_spread = get(attrs, "prob_vaccinated_and_spread", Tuple(parameters.prob_vaccinated_and_spread))
    # parameters.social_distancing = get(attrs, "social_distancing", parameters.social_distancing)
    # parameters.step_size = get(attrs, "step_size", parameters.step_size)
    

    percentage_masked = Float64(get(attrs, "percentage_masked", parameters.percentage_masked))
    update_masked_agents!(model, percentage_masked, updated)

    percentage_vaccinated = get(attrs, "percentage_vaccinated", parameters.percentage_vaccinated)
    percentage_vaccinated = float.(percentage_vaccinated)
    update_vaccinated_agents!(model, percentage_vaccinated, updated)

    updated["step"] = parameters.step
    if length(updated) == 1
        return
    end
    fname = "output/" * parameters.name * ".updates"
        	if !isfile(fname)
		if !isdir("output")
			mkdir("output")
		end
		touch(fname)
	end
	open(fname, "a") do io
		write(io, JSON.json(updated) * "\n")
	end

end

function _update_param_field(model::ABM, param::Symbol, new_value::Any, updateDict::Dict)
    old_value = getfield(model.parameters, param)
    if old_value != new_value
        setfield!(model.parameters, param, new_value)
        updateDict[string(param)] = Dict("old" => old_value, "new" => new_value)
    end
end

function _update_param(model::ABM, param::Symbol, updateDict::Dict)
    getfield(model.parameters, param)
end

function update_masked_agents!(model::ABM, percentage_masked::Float64,  updateDict::Dict)
    # Mask or unmask agents in the model based on the `percentage_masked` parameter which defines the percentage of 
    # alive agents who are masked at any time.
    
    n_total = 0
    masked = []
    unmasked = []

    for (_, agent::Person) in model.agents
        !is_alive(agent) && continue
        n_total += 1
        push!(agent.is_masked ? masked : unmasked, agent.id)
    end

    num_masked_expected = clamp(floor(Int64, (percentage_masked / 100.0) * n_total), 1, n_total)

    if length(masked) < num_masked_expected
        num_to_be_masked = min(num_masked_expected - length(masked), length(unmasked))
        Random.shuffle!(unmasked)
        for i = 1:num_to_be_masked
            model.agents[unmasked[i]].is_masked = true
        end
        println(length(masked), " agents were already masked")
        println(num_to_be_masked, " more agents were masked just now")
        _update_param_field(model, :percentage_masked, percentage_masked, updateDict)
    elseif num_masked_expected < length(masked)
        num_to_be_unmasked = length(masked) - num_masked_expected
        Random.shuffle!(masked)
        for i = 1:num_to_be_unmasked
            model.agents[masked[i]].is_masked = false
        end
        println(length(masked), " agents were already masked")
        println(num_to_be_unmasked, " agents were un-masked just now")
        _update_param_field(model, :percentage_masked, percentage_masked, updateDict)
    end

end

function update_vaccinated_agents!(model::ABM, percentage_vaccinated::Vector{Float64}, updateDict::Dict)
    # Vaccinate agents based on `percentage_vaccinated` parameter which defines the percentage of population which should get vaccinated in total

    n_total = 0
    vaccinated0 = []
    vaccinated1 = []
    vaccinated2 = []
        
    for (_, agent::Person) in model.agents
        !is_alive(agent) && continue
        n_total += 1
        n_shots = agent.vaccine_shots
        push!(n_shots === 0 ? vaccinated0 : n_shots === 1 ? vaccinated1 : vaccinated2, agent.id)
    end

    num_vaccine1_expected = clamp(floor(Int64, (percentage_vaccinated[1] / 100.0) * n_total), 0, n_total)
    num_vaccine2_expected = clamp(floor(Int64, (percentage_vaccinated[2] / 100.0) * n_total), 0, n_total)

    updated = false
    if length(vaccinated1) < num_vaccine1_expected
        num_to_be_vaccinated1 = min(num_vaccine1_expected - length(vaccinated1), length(vaccinated0))
        Random.shuffle!(vaccinated0)
        for i = 1:num_to_be_vaccinated1
            model.agents[vaccinated0[i]].vaccine_shots = 1
        end
        println(length(vaccinated1), " agents were already vaccinated with 1st dose")
        println(num_to_be_vaccinated1, " more agents were vaccinated with 1st dose just now")
        updated = true
    end
    
    if length(vaccinated2) < num_vaccine2_expected
        num_to_be_vaccinated2 = min(num_vaccine2_expected - length(vaccinated2), length(vaccinated1))
        Random.shuffle!(vaccinated1)
        for i = 1:num_to_be_vaccinated2
            model.agents[vaccinated1[i]].vaccine_shots = 2
        end
        println(length(vaccinated2), " agents were already vaccinated with 2nd dose")
        println(num_to_be_vaccinated2, " more agents were vaccinated with 2nd dose just now")
        updated = true
    end

    _update_param_field(model, :percentage_vaccinated, percentage_vaccinated, updateDict)

end

function model_params(model_name::String, params::Dict)::Parameters
    return _read_params(model_name, params)
end

end