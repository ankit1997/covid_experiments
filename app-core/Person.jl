module PersonMod

export Person, is

using Agents:ABM,move_agent!
using ..ParametersMod
using ..LocationMod
using ..UtilsMod
using ..JourneyMod

function move_person!(agent::Person, model::ABM, pos::NTuple{2,Float64})::Bool
	# Move an agent::Person to new location and update fields accordingly

	params = model.parameters

	# Get old/current location
	old_loc = params.Locations[agent.current_loc_id]

	# Get new location
	new_loc = LocationMod.location_by_pos(pos, params)
	if new_loc === nothing
		println("Can't find location for position: ", pos)
		return false
	end

	# Move agent to new location
	move_agent!(agent, pos, model)
	agent.current_loc_id = new_loc.id

	new_loc.capacity -= 1
	old_loc.capacity += 1

	if new_loc.type === HOSPITAL && isempty(agent.upcoming_pos)
		# Hospitalize agent
		change_infection_status!(agent, model, HOSPITALIZED)
	end

	return true

end

function move_person!(agent::Person, model::ABM)

	if !isempty(agent.upcoming_pos)
		new_pos = agent.upcoming_pos[1]
		if (new_pos[1] === NaN)
			println("Inside agent step, nan encountered")
		end
		new_loc = LocationMod.location_by_pos(new_pos, model.parameters)
		if new_loc.capacity > 0 || new_loc.id === agent.current_loc_id || new_loc.id === agent.home_loc_id
			popfirst!(agent.upcoming_pos)
			move_person!(agent, model, new_pos)
		elseif new_loc.capacity <= 0
			move_person!(agent, model, random_pos_in_loc(LocationMod.location_by_pos(agent.pos, model.parameters)))
		end
	end

end

function move_person!(agent::Person, model::ABM, steps::Int64)
	
	for _ = 1:steps
		move_person!(agent, model)
	end

end

function transmit!(a1::Person, a2::Person, model::ABM)

	params = model.parameters

	count(is_infected(a) for a in (a1, a2)) != 1 && return
	DECEASED in (a1.infection_status, a2.infection_status) && return
	
    infected, healthy = is_infected(a1) ? (a1, a2) : (a2, a1)
	prob_infection_spread = _get_prob_of_spread(infected, healthy, params)
	can_interact = at_location(a1, a2.current_loc_id) || (at_location(a1, EMPTY, params) && at_location(a2, EMPTY, params))

	if is_probable(prob_infection_spread) && can_interact
		if infected.is_asymptomatic
			change_infection_status!(healthy, model, ASYMPTOMATIC)
		else
			change_infection_status!(healthy, model, MILD)
		end
	end

end

function change_infection_status!(agent::Person, model::ABM, status::Symbol)

	if agent.infection_status != status

		agent.infection_status = status
		agent.infection_status_duration = 0

		if is(agent, HOSPITALIZED)
			# Agent is hospitalized
			empty!(agent.upcoming_pos)
		elseif is(agent, DECEASED)
			# Agent is deceased :(
			empty!(agent.upcoming_pos)
			model.parameters.Locations[agent.current_loc_id].capacity += 1
		elseif is(agent, RECOVERED)
			# Agent recovered from hospital
			empty!(agent.upcoming_pos)
		end

	end

end

function infection_dynamics!(agent::Person, model::ABM)

	_days_passed_in_stage(a::Person, d::Int64)::Bool = (a.infection_status_duration / model.parameters.num_steps_in_day) >= d
	loc = model.parameters.Locations[agent.current_loc_id]::Location
	num_steps_in_day = model.parameters.num_steps_in_day

	if is(agent, SUSCEPTIBLE)
		# do nothing for susceptible agent
		nothing
	elseif is(agent, MILD)
		if _days_passed_in_stage(agent, 2)
			new_state = is_probable(rand()) ? INFECTED : SEVERE
			change_infection_status!(agent, model, new_state)
		end
	elseif is(agent, PRESYMPTOMATIC)
		nothing
	elseif is(agent, ASYMPTOMATIC)
		nothing
	elseif is(agent, INFECTED)
		if _days_passed_in_stage(agent, 2)
			new_state = is_probable(0.6) ? SEVERE : RECOVERED
			change_infection_status!(agent, model, new_state)
		end
	elseif is(agent, SEVERE)
		if _days_passed_in_stage(agent, 5) && is_probable(0.7)
			change_infection_status!(agent, model, DECEASED)
		end
	elseif is(agent, HOSPITALIZED) && ParametersMod.is(loc, HOSPITAL)
		if ((4 * num_steps_in_day) < agent.infection_status_duration && is_probable(0.3))
			change_infection_status!(agent, model, RECOVERED)
			JourneyMod.plan_move_home!(agent, model)
			PersonMod.move_person!(agent, model, 3)
		elseif agent.infection_status_duration >= (7 * num_steps_in_day) && is_probable(0.7)
			change_infection_status!(agent, model, DECEASED)
		end
	elseif is(agent, RECOVERED)
		nothing
	end

	agent.infection_status_duration += 1

end

function get_move_prob(agent::Person)::Float64
	if agent.infection_status in (SUSCEPTIBLE, RECOVERED, ASYMPTOMATIC)
		return 0.9
	elseif agent.infection_status in (MILD,)
		return 0.8
	elseif agent.infection_status in (INFECTED,)
		return 0.4
	elseif agent.infection_status in (SEVERE,)
		return 0.1
	elseif agent.infection_status in (HOSPITALIZED,)
		return 0.0001
	end
end

function _get_prob_of_spread(infected::Person, healthy::Person, p::Parameters)::Float64
	# Get probability of infection spread between a infected and a healthy agent given they interact in close enough proximity

	very_low = 0.0001

	if infected.is_masked || healthy.is_masked
		# very low probability of spread if either is masked
		return very_low
	end

	if healthy.vaccine_shots > 0
		return p.prob_vaccinated_and_spread[healthy.vaccine_shots]
	end

	return healthy.prob_get_infected

end

end