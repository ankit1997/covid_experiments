module ModelMod

using ..ParametersMod:Parameters, Location, model_params, EMPTY, HOUSE, HOSPITAL, SUSCEPTIBLE, MILD, ASYMPTOMATIC, INFECTED, HOSPITALIZED, RECOVERED, DECEASED
using ..LocationMod:random_pos_in_loc,clamp_in_loc
using ..PersonMod:Person, move_person!
using ..UtilsMod:is_probable,distance
using Agents:ABM,ContinuousSpace,add_agent!,interacting_pairs
using Random:shuffle

function get_model(model_name::String, params::Dict)::ABM

	parameters = model_params(model_name, params)::Parameters
	println("Creating model for ", parameters.num_agents, " agents...")

	space2d = ContinuousSpace((parameters.world_height, parameters.world_width), 0.02)
	model = ABM(Person, space2d, properties=Dict{Symbol,Parameters}(:parameters => parameters))
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

# function social_distancing!(model::ABM)

# 	!model.parameters.social_distancing && return

# 	for loc in model.parameters.Locations
# 		agents = [agent.id for (_, agent::Person) in model.agents if agent.current_loc_id === loc.id && agent.infection_status !==  DECEASED]
# 		n = length(agents)
# 		for _ = 1:10
# 			force_dict = Dict()
# 			for i = 1:n
# 				for j = 1:n
# 					if i === j
# 						continue
# 					end
					
# 					a1 = model.agents[i]
# 					a2 = model.agents[j]

# 					d = distance(a1.pos, a2.pos)
# 					(d == 0.0 || d > 1.0) && continue
					
# 					f = _normalize((a1.pos[1] - a2.pos[1], a1.pos[2] - a2.pos[2]))

# 					f_old1 = get(force_dict, a1, (0.0, 0.0))
# 					force_dict[a1] = _normalize((f_old1[1] + f[1], f_old1[2] + f[2]))

# 					f_old2 = get(force_dict, a2, (0.0, 0.0))
# 					force_dict[a2] = _normalize((f_old2[1] - f[1], f_old2[2] - f[2]))
# 				end
# 			end
# 			for (agent, force) in force_dict
# 				pos = agent.pos
# 				new_pos = pos[1] + 2 * force[1], pos[2] + 2 * force[2]
# 				new_pos = clamp_in_loc(new_pos, model.parameters.Locations[agent.current_loc_id])
# 				move_person!(agent, model, new_pos)
# 			end
# 		end
# 	end

# end

function _normalize(vector::NTuple{2,Float64})
	if vector === (0.0, 0.0)
		return vector
	end
	d = vector[1]^2 + vector[2]^2
	return (vector[1] / d, vector[2] / d)
end

end