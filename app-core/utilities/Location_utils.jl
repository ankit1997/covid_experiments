module LocationUtilsModule

using Agents:ABM
using Random:shuffle

using ..PersonModule
using ..ParametersModule
using ..LocationModule
using ..CommonUtilsModule

export plan_move_random!, plan_move_home!, plan_move_hospital!, plan_move_same_loc!, plan_move_isolation!

function plan_move_random!(agent::Person, model::ABM)::Bool

	possible_dest = filter(loc::Location -> (loc.type === HOUSE || loc.type === COMMON) && loc.capacity > 0 && is_probable(loc.prob_come_from_diff_loc), model.parameters.Locations)
	isempty(possible_dest) && return false
	
	current_loc = pos2loc(agent.pos, model.parameters)
	current_pos = isempty(agent.upcoming_pos) ? agent.pos : last(agent.upcoming_pos)
	next_loc = rand(possible_dest)
	
	_plan_move_next_loc!(agent, model, current_pos, current_loc, next_loc)

end

function plan_move_home!(agent::Person, model::ABM)::Bool

	old_loc = pos2loc(agent.pos, model.parameters)
	
	(agent.home_loc_id === -1 || agent.home_loc_id === old_loc.id) && return false

	current_loc = pos2loc(agent.pos, model.parameters)
	home = model.parameters.Locations[agent.home_loc_id]
	n = length(agent.upcoming_pos)
	
	success = _plan_move_next_loc!(agent, model, agent.pos, current_loc, home)
	if success
		agent.upcoming_pos = agent.upcoming_pos[n + 1:end]
	end

	return success

end

function plan_move_hospital!(agent::Person, model::ABM)::Bool

	agent.infection_status !== SEVERE && return false

	hospitals = filter(loc::Location -> loc.type === HOSPITAL && loc.capacity > 0, model.parameters.Locations)
	isempty(hospitals) && return false

	hospital = rand(hospitals)
	n = length(agent.upcoming_pos)
	current_loc = pos2loc(agent.pos, model.parameters)
	
	success = _plan_move_next_loc!(agent, model, agent.pos, current_loc, hospital)
	if success
		agent.upcoming_pos = agent.upcoming_pos[n + 1:end]
	end

	return success

end

function plan_move_isolation!(agent::Person, model::ABM)::Bool

	isolation_spots = filter(loc::Location -> loc.type === ISOLATION && loc.capacity > 0, model.parameters.Locations)
	isempty(isolation_spots) && return false

	isolation_centre = rand(isolation_spots)
	n = length(agent.upcoming_pos)
	current_loc = pos2loc(agent.pos, model.parameters)
	
	success = _plan_move_next_loc!(agent, model, agent.pos, current_loc, isolation_centre)
	if success
		agent.upcoming_pos = agent.upcoming_pos[n + 1:end]
	end

	return success

end
    
function plan_move_same_loc!(agent::Person, model::ABM; step_interpolation::Int64=2, force_now::Bool=false)::Bool

	old_pos = isempty(agent.upcoming_pos) || force_now ? agent.pos : last(agent.upcoming_pos)
	loc = pos2loc(old_pos, model.parameters)
	next_pos = random_pos_in_loc(loc)

	for i = 1:step_interpolation
		pos_i = _interpolate.(old_pos, next_pos, 0, i, step_interpolation)
		if force_now
			pushfirst!(agent.upcoming_pos, pos_i)
		else
			push!(agent.upcoming_pos, pos_i)
		end
	end

	return true

end

function _plan_move_next_loc!(agent::Person, model::ABM, old_pos::NTuple{2,Float64}, old_loc::Location, next_loc::Location, step_interpolation::Int64=3)::Bool

	old_loc.id === next_loc.id && return true

	path = _get_travel_path(old_loc, next_loc, model.parameters)
	path === nothing && return false
	
    for loc_id in path[2:end]
		# Find random position inside location of the path
		loc = model.parameters.Locations[loc_id]
		pos = random_pos_in_loc(loc)
		for i = 1:step_interpolation
			pos_i = _interpolate.(old_pos, pos, 0, i, step_interpolation)
			push!(agent.upcoming_pos, pos_i)
		end
		old_pos = pos
	end

	return true

end

function _get_travel_path(start_loc::Location, end_loc::Location, params::Parameters)
	
	# Find previous elements in path to the end location
	start_ind = loc_id2ind(start_loc.id, params)
	end_ind = loc_id2ind(end_loc.id, params)
    
	previous = _find_path(start_ind, end_ind, params)

    path = []
	current_ind = end_ind
	while current_ind !== (-1, -1)
		push!(path, current_ind)
		current_ind = previous[current_ind...]
	end

	reverse!(path)

	if path[1] === start_ind
		return map(p -> loc_ind2id(p, params), path)
	end

	return nothing

end

function _find_path(start_ind::NTuple{2,Int64}, end_ind::NTuple{2,Int64}, params::Parameters)::Matrix{NTuple{2,Int64}}
	
	queue = []
	push!(queue, start_ind)

	visited = fill(false, size(params.map))
	visited[start_ind...] = true
    
	previous = fill((-1, -1), size(params.map))
	dr = [-1, 1, 0, 0]
	dc = [0, 0, 1, -1]
        
	while !isempty(queue)
		current_ind = popat!(queue, rand(1:length(queue)))
		current_ind === end_ind && break
		for i = shuffle(1:4)
			next_ind = (current_ind[1] + dr[i], current_ind[2] + dc[i])
			if is_valid_loc_ind(next_ind, params) && !visited[next_ind...] && (params.map[next_ind...] === EMPTY || next_ind === end_ind)
				push!(queue, next_ind)
				visited[next_ind...] = true
				previous[next_ind...] = current_ind
			end
		end
	end

	return previous

end

function _interpolate(old::Float64, new::Float64, t0::Int64, t::Int64, tn::Int64)
	return (tn == t0) ? new : (((tn - t) * old + (t - t0) * new) / (tn - t0))
end

end