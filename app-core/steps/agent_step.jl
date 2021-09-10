module AgentStepModule

using Agents:ABM,move_agent!
using ..PersonModule
using ..ParametersModule:pos2loc
using ..LocationModule
using ..TransmissionBlock:transmission!
using ..MoveBlock
using ..ModelUtilsModule:change_infection_status!
using ..LocationUtilsModule
using ..CommonUtilsModule

export agent_step_basic!

function agent_step_basic!(agent::Person, model::ABM)

	agent.infection_status === DECEASED && return

    _plan_movement(agent, model)

    _movement!(agent, model)

    _status_update!(agent, model)

end

function _plan_movement(agent::Person, model::ABM)

    # Hospitalized agents won't go anywhere else
    agent.infection_status === HOSPITALIZED && return

    current_loc = pos2loc(agent.pos, model.parameters)
    dest_loc = !isempty(agent.upcoming_pos) ? pos2loc(last(agent.upcoming_pos), model.parameters) : nothing
    num_days_inf_state = agent.infection_status_duration % model.parameters.num_steps_in_day

    # Move in same location if can't move out
    !is_probable(current_loc.prob_move_to_diff_loc) && ((is_probable(current_loc.prob_move_in_same_loc) && return plan_move_same_loc!(agent, model, force_now=true)) || return)

    # Severely infected agents will try to go/stay at home unless going to hospital/isolation
    any_status(agent, [SEVERE]) && 
        (dest_loc === nothing || (dest_loc.type !== HOSPITAL && dest_loc.type !== ISOLATION)) && 
        (dest_loc === nothing || dest_loc.id !== agent.home_loc_id) && 
        (length(empty!(agent.upcoming_pos)) === 0 && return plan_move_home!(agent, model))

    # Don't plan any movement if going to hospital
    dest_loc !== nothing && dest_loc.type === HOSPITAL && return

    # Infected/Severe agents should visit hospital
    should_visit_hospital = ((any_status(agent, [INFECTED]) && num_days_inf_state ≥ 4) || (any_status(agent, [SEVERE]) && num_days_inf_state ≥ 2)) &&
                            is_probable(model.parameters.prob_visit_hospital[agent.infection_status])
    should_visit_hospital && plan_move_hospital!(agent, model) && return

    is_going_to_home = dest_loc !== nothing && dest_loc.id === agent.home_loc_id
    is_going_to_home && return

    agent.is_home_quarantine && current_loc.id !== agent.home_loc_id && plan_move_home!(agent, model) && return
    agent.is_home_quarantine && current_loc.id === agent.home_loc_id && plan_move_same_loc!(agent, model) && return

    any_status(agent, [INFECTED, SEVERE]) && num_days_inf_state ≥ 2 && is_probable(model.parameters.isolation) && plan_move_isolation!(agent, model) && return

    !isempty(agent.upcoming_pos) && return

    hour = model.parameters.step % model.parameters.num_steps_in_day
    (19 ≤ hour || hour ≤ 7) && current_loc.id === agent.home_loc_id && return
    if (19 ≤ hour || hour ≤ 7) && current_loc.id !== agent.home_loc_id
        plan_move_home!(agent, model) && return
    end

    any_status(agent, [SEVERE]) && current_loc.id !== agent.home_loc_id && return plan_move_home!(agent, model)
is_probable(0.5) ? plan_move_random!(agent, model) : is_probable(current_loc.prob_move_in_same_loc) ? plan_move_same_loc!(agent, model) : plan_move_home!(agent, model)

end


function _movement!(agent::Person, model::ABM; n::Int64=1)
    
    for _ = 1:n
        isempty(agent.upcoming_pos) && return
        move_person!(agent, model, popfirst!(agent.upcoming_pos))
    end

end

function _status_update!(agent::Person, model::ABM)

    # https://i.insider.com/5f7dee2b94fce90018f7ba8d?width=1000&format=jpeg&auto=webp

    current_loc = pos2loc(agent.pos, model.parameters)

    if current_loc.type === ISOLATION
        if _passed(agent, 10)
            recover = is_probable(0.8)
            change_infection_status!(agent, model, recover ? RECOVERED : DECEASED)
            if recover
            empty!(agent.upcoming_pos)
    plan_move_home!(agent, model) || plan_move_random!(agent, model)
                _movement!(agent, model; n=5)
            end
        end

    elseif agent.infection_status === MILD && _passed(agent, 5)
        change_infection_status!(agent, model, INFECTED)
    
    elseif agent.infection_status === ASYMPTOMATIC && _passed(agent, 5)
        change_infection_status!(agent, model, SUSCEPTIBLE)

    elseif agent.infection_status === INFECTED && _passed(agent, 4)
        change_infection_status!(agent, model, is_probable(.15) ? SEVERE : RECOVERED)

    elseif agent.infection_status === SEVERE && current_loc.type === HOSPITAL
        change_infection_status!(agent, model, HOSPITALIZED)

    elseif agent.infection_status === SEVERE && _passed(agent, 6)
        change_infection_status!(agent, model, DECEASED)
    
    elseif agent.infection_status === HOSPITALIZED
        if _passed(agent, 10) && is_probable(0.7)
            change_infection_status!(agent, model, DECEASED)
        elseif _passed(agent, 4) && is_probable(0.3)
			change_infection_status!(agent, model, RECOVERED)
			empty!(agent.upcoming_pos)
            plan_move_home!(agent, model) || plan_move_random!(agent, model)
    _movement!(agent, model; n=5)
		end

    end

    agent.infection_status_duration += 1

end

function _passed(agent::Person, n::Int64)::Bool
    agent.infection_status_duration / 24 >= n
end

end