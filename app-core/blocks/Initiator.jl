module InitiatorBlock

using Random:shuffle
using Agents:ABM,ContinuousSpace,add_agent!,interacting_pairs, random_activation

using ..ParametersModule
using ..PersonModule
using ..LocationModule

export get_model

function get_model(model_name::String, params::Dict)::ABM

	parameters = _read_params(model_name, params)::Parameters
	println("Creating model for ", parameters.num_agents, " agents...")

	space2d = ContinuousSpace((parameters.world_height, parameters.world_width), 0.02)
	model = ABM(Person, space2d, scheduler=random_activation, properties=Dict{Symbol,Any}(:parameters => parameters))
	_init_world(model)
	return model
	
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
    num_shops = params["location"]["num_shops"]
    num_isolation = 1
    num_empty = map_dimens[1] * map_dimens[2] - (num_houses + num_hospitals + num_shops + num_isolation)

    loc_width = 2.0
    loc_height = 2.0

	location_map = shuffle(reshape([fill(HOUSE, num_houses);  fill(HOSPITAL, num_hospitals); fill(COMMON, num_shops); fill(EMPTY, num_empty); fill(ISOLATION, num_isolation)], map_dimens))
	locations = _init_locations(location_map, map_item_capacity, loc_width, loc_height)

    prob_visit_hospital = Dict()
    prob_visit_hospital[SUSCEPTIBLE] = 0.0001
    prob_visit_hospital[MILD] = 0.1
    prob_visit_hospital[ASYMPTOMATIC] = 0.001
    prob_visit_hospital[INFECTED] = 0.6
    prob_visit_hospital[SEVERE] = 0.9
    prob_visit_hospital[HOSPITALIZED] = 0.0
    prob_visit_hospital[RECOVERED] = 0.0001
    prob_visit_hospital[DECEASED] = 0.0

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
                            params["social_distancing"],
                            params["quarantine"] / 100.0,
                            params["isolation"] / 100.0)
    
    return parameters

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
            prob_move_in_same_loc = type === HOSPITAL || type === ISOLATION ? 0.001 : 0.9
            prob_move_to_diff_loc = type === ISOLATION ? 0.0 : type === HOSPITAL ? 0.001 : 0.9
            prob_come_from_diff_loc = type === HOUSE ? 0.4 : type === EMPTY ? 0.6 : 0.9

            social_distancing = 0.01

			loc = Location(id, type, capacity, xmin, xmax, ymin, ymax, social_distancing, prob_move_in_same_loc, prob_move_to_diff_loc, prob_come_from_diff_loc)
            push!(locations, loc)
			id += 1
		end
	end
    	
	return locations

end
    
function _init_world(model::ABM)

    n = model.parameters.num_agents
	infected = rand(1:n, model.parameters.initial_infections)
	
	num_masked = floor(Int64, (model.parameters.percentage_masked * n / 100.0))
	masked = rand(1:n, num_masked)

	vaccine1 = floor(Int64, (model.parameters.percentage_vaccinated[1] * n / 100.0))
	vaccine2 = floor(Int64, (model.parameters.percentage_vaccinated[2] * n / 100.0))
	vaccine_shots = shuffle(split("1"^vaccine1 * "2"^vaccine2 * "0"^(n - vaccine1 - vaccine2), ""))

	asymptomatic = rand(1:n, floor(Int64, n * 0.1))

    empty_locs = filter(loc -> loc.type === EMPTY && loc.capacity > 0, model.parameters.Locations)

	for i = 1:n
		
        available_locs = filter(loc -> loc.type === HOUSE && loc.capacity > 0, model.parameters.Locations)
        
		loc = isempty(available_locs) ? rand(empty_locs) : rand(available_locs)
		pos = random_pos_in_loc(loc)
		is_asymptomatic = i in asymptomatic

		# add agent into the model at selected location
		infection_status = (i in infected ? (is_asymptomatic ? ASYMPTOMATIC : MILD) : SUSCEPTIBLE)
		is_masked = (i in masked)
		num_vaccine_shots = parse(Int64, vaccine_shots[i])
        immunity = rand()

		add_agent!(pos, model, loc.id, [], infection_status, 0, is_masked, num_vaccine_shots, immunity, is_asymptomatic, false)
		model.parameters.Locations[loc.id].capacity -= 1

	end

end

end