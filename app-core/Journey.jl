module JourneyMod

using ..ParametersMod
using ..LocationMod
using ..UtilsMod
using Agents:ABM

function plan_cross_loc_move!(agent::Person, model::ABM, next_loc::Location)::Bool
	# Plan journey of `agent` to `next_loc`

	params = model.parameters::Parameters
	old_pos = isempty(agent.upcoming_pos) ? agent.pos : last(agent.upcoming_pos)
	old_loc = LocationMod.location_by_pos(old_pos, params)

	if old_loc.id === next_loc.id
		# If agent is already at the destination location, then return
		return false
	end

	# Get a random path from current location to next location
	path = LocationMod.get_travel_path(old_loc, next_loc, params)
	if path === nothing
		# If no possible path exists, then return
		return false
	end
	
	for loc_id in path[2:end]
		# Find random position inside location of the path
		loc = params.Locations[loc_id]
		pos = LocationMod.random_pos_in_loc(loc)

		# Interpolate travel to this position from old position
		steps = LocationMod.interpolate_steps(old_pos, pos, loc, 2)
		append!(agent.upcoming_pos, steps)
		old_pos = pos

	end

	return true

end

function plan_cross_loc_move!(agent::Person, model::ABM)::Bool

	possible_dest = filter(loc::Location -> can_visit_loc(loc) && loc.type !== HOSPITAL, model.parameters.Locations)
	isempty(possible_dest) && return false
	
	new_loc = rand(possible_dest)
	plan_cross_loc_move!(agent, model, new_loc)

end

function plan_move_home!(agent::Person, model::ABM)::Bool
	# Plan visit to home

	pos = isempty(agent.upcoming_pos) ? agent.pos : last(agent.upcoming_pos)
	current_loc = LocationMod.location_by_pos(pos, model.parameters)
	(agent.home_loc_id === -1 || agent.home_loc_id === current_loc.id) && return false

	home = model.parameters.Locations[agent.home_loc_id]
	plan_cross_loc_move!(agent, model, home)

end

function plan_move_hospital!(agent::Person, model::ABM)::Bool
	# Plan visit to hospital. Drops current path and go to a random hospital location

	hospitals = filter(loc::Location -> is(loc, HOSPITAL) && can_visit_loc(loc), model.parameters.Locations)
	isempty(hospitals) && return false

	hospital = rand(hospitals)
	empty!(agent.upcoming_pos)
	return plan_cross_loc_move!(agent, model, hospital)

end

function plan_same_loc_move!(agent::Person, model::ABM)
	# Move agent within current location

	pos = isempty(agent.upcoming_pos) ? agent.pos : last(agent.upcoming_pos)
	loc = LocationMod.location_by_pos(pos, model.parameters)

	# Add new coordinates for the agent to move in next few steps
	new_pos = LocationMod.random_pos_in_loc(loc)
	
	# interpolate the steps from old->new position
	steps = LocationMod.interpolate_steps(pos, new_pos, loc, 2)
	append!(agent.upcoming_pos, steps)

end

function schedule_hospital_visit!(agent::Person, model::ABM)::Bool

	is_agent_at_hospital = agent.infection_status === HOSPITALIZED
	is_agent_going_to_hospital = false
	
	if !isempty(agent.upcoming_pos)
		destination_pos = last(agent.upcoming_pos)
		destination = LocationMod.location_by_pos(destination_pos, model.parameters)
		if (destination === nothing)
			println("WARN: destination === nothing")
			return false
		end
		is_agent_going_to_hospital = is(destination, HOSPITAL)
	end

	return !is_agent_at_hospital && 
			!is_agent_going_to_hospital && 
			plan_move_hospital!(agent, model)

end

function can_visit_loc(loc::Location)::Bool
	return loc.capacity > 0 && is_probable(loc.prob_come_from_diff_loc)
end

end