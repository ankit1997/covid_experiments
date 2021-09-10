module ModelStepModule

using Agents:ABM,interacting_pairs
using ..PersonModule
using ..TransmissionBlock:transmission!
using ..SocialDistancingBlock

export model_step_basic!

function model_step_basic!(model::ABM)

	# for (_, agent::Person) in model.agents
	# 	any_status(agent, [DECEASED, HOSPITALIZED]) && continue
	# 	social_distancing!(agent, model)
	# end

	transmission!(model)
	
	model.parameters.step += 1
	if (model.parameters.step % model.parameters.num_steps_in_day) === 0
    	model.parameters.day += 1
	end

    any([is_infected(agent) for (_, agent::Person) in model.agents]) && return
    model.parameters.stop_flag = true

end

end