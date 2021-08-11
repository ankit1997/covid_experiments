module ModelMod

using ..ParametersMod:Parameters, model_params, EMPTY, HOUSE, HOSPITAL, SUSCEPTIBLE, MILD, ASYMPTOMATIC, INFECTED, HOSPITALIZED, RECOVERED, DECEASED
using ..LocationMod:random_pos_in_loc
using ..PersonMod:Person
using ..UtilsMod:is_probable
using Agents:ABM,ContinuousSpace,add_agent!
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
		is_asymptomatic = is_probable(0.2)

		# add agent into the model at selected location
		infection_status = (i in infected ? (is_asymptomatic ? ASYMPTOMATIC : MILD) : SUSCEPTIBLE)
		is_masked = (i in masked)
		num_vaccine_shots = parse(Int64, vaccine_shots[i])

		add_agent!(pos, model, loc.id, loc.id, [], infection_status, 0, is_masked, num_vaccine_shots, rand(), is_asymptomatic)
		model.parameters.Locations[loc.id].capacity -= 1
        
	end
	
end

end