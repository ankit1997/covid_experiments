module ModelMod

using ..ParametersMod:Parameters, model_params, EMPTY, HOUSE, HOSPITAL, SUSCEPTIBLE, MILD, ASYMPTOMATIC, INFECTED, HOSPITALIZED, RECOVERED, DECEASED
using ..LocationMod:random_pos_in_loc
using ..PersonMod:Person
using ..UtilsMod:is_probable
using Agents:ABM,ContinuousSpace,add_agent!

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

	for i = 1:n
		
        available_houses = filter(loc -> loc.type === HOUSE && loc.capacity > 0, model.parameters.Locations)
        if isempty(available_houses)
			println("WARN: No house available from agent no. ", i)
			return
		end

		loc = rand(available_houses)
		pos = random_pos_in_loc(loc)
		is_asymptomatic = is_probable(0.2)

		# add agent into the model at selected location
		infection_status = (i in infected ? (is_asymptomatic ? ASYMPTOMATIC : MILD) : SUSCEPTIBLE)
		add_agent!(pos, model, loc.id, loc.id, [], infection_status, 0, false, 0, rand(), is_asymptomatic)
		model.parameters.Locations[loc.id].capacity -= 1
        
	end
	
end

end