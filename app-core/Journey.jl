module JourneyMod

using ..ParametersMod
using ..LocationMod
using ..UtilsMod
using Agents:ABM

function plan_cross_loc_move!(agent::Person, model::ABM, next_loc::Location)::Bool
	# Plan journey of `agent` to `next_loc`
	
	if agent.current_loc_id === next_loc.id
		# If agent is already at the destination location, then return
		return false
	end
    
	params = model.parameters::Parameters

	current_loc = params.Locations[agent.current_loc_id]
	
	# Get all possible paths from current location to next location
	paths = LocationMod.get_travel_path(current_loc, next_loc, params)
	if length(paths) === 0
		# If no possible path exists, then return
		return false
	end

	# Select a random path from list of possible paths
	path = rand(paths)
	
	old_pos = agent.pos
	for loc_id in path

		# Find random position inside location of the path
		loc = params.Locations[loc_id]
		pos = LocationMod.random_pos_in_loc(loc)

		# Interpolate travel to this position from old position
		local steps = LocationMod.interpolate_steps!(old_pos, pos, loc, 2)
        if !isempty(steps)
            append!(agent.upcoming_pos, steps)
			# Update old position
			old_pos = deepcopy(last(steps))
        end

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

	agent.home_loc_id === agent.current_loc_id && return false

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

	loc = model.parameters.Locations[agent.current_loc_id]

	# Add new coordinates for the agent to move in next few steps
	new_pos = LocationMod.random_pos_in_loc(loc)
	
	# interpolate the steps from old->new position
	steps = LocationMod.interpolate_steps!(agent.pos, new_pos, loc, 2)
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
			is_probable(model.parameters.prob_visit_hospital[agent.infection_status]) &&
			plan_move_hospital!(agent, model)

end

function can_visit_loc(loc::Location)::Bool
	return loc.capacity > 0 && is_probable(loc.prob_come_from_diff_loc)
end

end