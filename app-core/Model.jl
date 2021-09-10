module ModelMod

using ..ParametersMod:Parameters, Location, model_params, EMPTY, HOUSE, HOSPITAL, SUSCEPTIBLE, MILD, ASYMPTOMATIC, INFECTED, HOSPITALIZED, RECOVERED, DECEASED,loc_id2ind
using ..LocationMod:random_pos_in_loc,clamp_in_loc,location_by_pos
using ..PersonMod:Person, move_person!
using ..UtilsMod:is_probable,distance
using Agents:ABM,ContinuousSpace,add_agent!,interacting_pairs, random_activation
using Random:shuffle

function get_model(model_name::String, params::Dict)::ABM

	parameters = model_params(model_name, params)::Parameters
	println("Creating model for ", parameters.num_agents, " agents...")

	space2d = ContinuousSpace((parameters.world_height, parameters.world_width), 0.02)
	model = ABM(Person, space2d, scheduler=random_activation, properties=Dict{Symbol,Any}(:parameters => parameters, :agents_processed => 0))
	_init_world(model)
	return model
	
end

function _init_world(model::ABM)

    n = model.parameters.num_agents
	infected = rand(1:n, model.parameters.initial_infections)
	
	num_masked = floor(Int64, (model.parameters.percentage_masked * n / 100.0))
	masked = rand(1:n, num_masked)

	vaccine1 = floor(Int64, (model.parameters.percentage_vaccinated[1] * n / 100.0))
	vaccine2 = floor(Int64, (model.parameters.percentage_vaccinated[2] * n / 100.0))
	vaccine_shots = shuffle(split("1"^vaccine1 * "2"^vaccine2 * "0"^(n - vaccine1 - vaccine2), ""))

	asymptomatic = rand(1:n, floor(Int64, n * 0.2))

	for i = 1:n
		
        available_locs = filter(loc -> loc.type === HOUSE && loc.capacity > 0, model.parameters.Locations)
        if isempty(available_locs)
			available_locs = filter(loc -> loc.type === EMPTY && loc.capacity > 0, model.parameters.Locations)
			if isempty(available_locs)
				println("WARN: No place available from agent no. ", i)
				return
			end
		end

		loc = rand(available_locs)
		pos = random_pos_in_loc(loc)
		is_asymptomatic = i in asymptomatic

		# add agent into the model at selected location
		infection_status = (i in infected ? (is_asymptomatic ? ASYMPTOMATIC : MILD) : SUSCEPTIBLE)
		is_masked = (i in masked)
		num_vaccine_shots = parse(Int64, vaccine_shots[i])

		add_agent!(pos, model, loc.id, [], infection_status, 0, is_masked, num_vaccine_shots, rand(), is_asymptomatic)
		model.parameters.Locations[loc.id].capacity -= 1
        
	end
	
end

function _add_agents!(model::ABM, n::Int64)
	empty = [loc for loc in model.parameters.Locations if loc.type === EMPTY]
	for _ = 1:n
		home = rand(empty)
		pos = random_pos_in_loc(home)
		add_agent!(pos, model, home.id, [], SUSCEPTIBLE, 0, false, 0, rand(), false)
	end
	println(n, " agents added at step: ", model.parameters.step)
end

function social_distancing!(model::ABM)

	model.parameters.social_distancing == 0 && return

	for loc in model.parameters.Locations
		agents = [agent.id for (_, agent::Person) in model.agents if location_by_pos(agent.pos, model.parameters).id === loc.id && agent.infection_status !==  DECEASED]
		length(agents) === 0 && continue
		agents = rand(agents, floor(Int64, (model.parameters.social_distancing * length(agents)) / 100.0))
		n = length(agents)
		force_dict = Dict()
		for i = 1:n
			for j = 1:n
				i === j && continue
				a1 = model.agents[i]
				a2 = model.agents[j]

				d = distance(a1.pos, a2.pos)
				(d == 0.0 || d > 0.3) && continue
				
				d_a12 = unit_vec((a1.pos[1] - a2.pos[1], a1.pos[2] - a2.pos[2]))
				f_a12 = (1.0 / (d_a12[1] == 0.0 ? (1.0 / 0.0) : d_a12[1]), 1.0 / (d_a12[2] == 0.0 ? (1.0 / 0.0) : d_a12[2]))
				f_old = get(force_dict, a1, (0.0, 0.0))
				f_new = unit_vec((f_a12[1] + f_old[1], f_a12[2] + f_old[2]))
				force_dict[a1] = f_new


			end
		end
		# if length(force_dict) > 0
		# 	println("Step: ", model.parameters.step)
		# 	println("Social distancing on ", length(force_dict), " for location: ", loc.id)
		# 	println(loc_id2ind(loc.id, model.parameters))
		# 	display(force_dict)
		# end
		
		for (agent, force) in force_dict
			pos = agent.pos
			new_pos = pos[1] + force[1], pos[2] + force[2]
			new_pos = clamp_in_loc(new_pos, loc)
			move_person!(agent, model, new_pos)
		end
		
	end

end

function unit_vec(v::NTuple{2,Float64})
	# return a unit vector of a given vector
	m = distance(v, (0.0, 0.0))
	return v[1] / m, v[2] / m
end

end