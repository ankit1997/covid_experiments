module LocationMod

using ..ParametersMod:Location,Person,Parameters,loc_id2ind,loc_ind2id,EMPTY
using ..UtilsMod

using Random:shuffle

export random_pos_in_loc

E = 0.001

function location_by_pos(pos::NTuple{2,Float64}, p::Parameters)

	if !(0.0 <= pos[1] <= p.world_width) || !(0.0 <= pos[2] <= p.world_height)
		return nothing
	end

	ROWS, _ = size(p.map)

	col = ceil(Int64, pos[1] / p.loc_width)
	row = ROWS + 1 - ceil(Int64, pos[2] / p.loc_height)
	id = loc_ind2id((row, col), p)
	
	return p.Locations[id]

end

function random_pos_in_loc(loc::Location)::NTuple{2,Float64}
    (random_in_range(loc.x_min + E, loc.x_max - E), random_in_range(loc.y_min + E, loc.y_max - E))
end

function is_valid_loc_ind(ind::NTuple{2,Int64}, p::Parameters)
	ROWS, COLUMNS = size(p.map)
    (1 <= ind[1] <= ROWS && 1 <= ind[2] <= COLUMNS)
end

function find_path(start_ind::NTuple{2,Int64}, end_ind::NTuple{2,Int64}, params::Parameters)::Matrix{NTuple{2,Int64}}
	
	queue = []
	push!(queue, start_ind)

	visited = fill(false, size(params.map))
	visited[start_ind...] = true

	previous = fill((-1, -1), size(params.map))
	dr = [-1, 1, 0, 0]
	dc = [0, 0, 1, -1]

	while !isempty(queue)
		current_ind = popfirst!(queue)
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

function get_travel_path(start_loc::Location, end_loc::Location, params::Parameters)
	
	# Find previous elements in path to the end location
	start_ind = loc_id2ind(start_loc.id, params)
	end_ind = loc_id2ind(end_loc.id, params)

	previous = find_path(start_ind, end_ind, params)

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

function interpolate_steps(old::NTuple{2,Float64}, new::NTuple{2,Float64}, new_loc::Location, n::Int64)::Array{NTuple{2,Float64}}

    interpolated_steps = []
	oldX, oldY = old
	newX, newY = new
	
	t0 = 1
	tn = n

	for i = t0:tn
		# calculate new interim positions by linear interpolation
		interimX = interpolate(oldX, newX, i, t0, tn)
		interimY = interpolate(oldY, newY, i, t0, tn)
		xy = (interimX, interimY)
		push!(interpolated_steps, xy)
	end

    return interpolated_steps

end

function clamp_in_loc(pos::NTuple{2,Float64}, loc::Location)::NTuple{2,Float64}
	println("  Clamping ", pos, " inside ", loc)
    res = (clamp(pos[1], loc.x_min + E, loc.x_max - E), clamp(pos[2], loc.y_min + E, loc.y_max - E))
	println("    - ", res)
	return res
end

end