module LocationMod

using ..ParametersMod:Location,Parameters,loc_id2ind,loc_ind2id,EMPTY
using ..UtilsMod

export random_pos_in_loc

E = 0.001

function is_loc_ind_empty(ind::NTuple{2,Int64}, p::Parameters)
    p.map[ind...] === EMPTY
end

function is_inside_loc(x::Float64, y::Float64, loc::Location)::Bool
	(loc.x_min <= x <= loc.x_max && loc.y_min <= y <= loc.y_max)
end

function is_inside_loc(pos::NTuple{2,Float64}, loc::Location)::Bool
	is_inside_loc(pos[1], pos[2], loc)
end

function location_by_pos(pos::NTuple{2,Float64}, p::Parameters)

	if !(0.0 <= pos[1] <= p.world_width) || !(0.0 <= pos[2] <= p.world_height)
		return nothing
	end

	ROWS, COLUMNS = size(p.map)

	col = ceil(Int64, pos[1] / p.loc_width)
	# row = ROWS + 1 - ceil(Int64, pos[2] / p.loc_height)
	row = ceil(Int64, pos[2] / p.loc_height)
	id = (row - 1) * COLUMNS + col
	
	return p.Locations[id]

end

function random_pos_in_loc(loc::Location)::NTuple{2,Float64}
    (random_in_range(loc.x_min + E, loc.x_max - E), random_in_range(loc.y_min + E, loc.y_max - E))
end

function is_valid_loc_ind(ind::NTuple{2,Int64}, p::Parameters)
	ROWS, COLUMNS = size(p.map)
    (1 <= ind[1] <= ROWS && 1 <= ind[2] <= COLUMNS)
end

function _get_all_paths_helper(source_ind::NTuple{2,Int64}, destination_ind::NTuple{2,Int64}, visited::Matrix{Bool}, 
                            path::Array{Int64}, all_paths::Vector{Vector{Int64}}, p::Parameters)

    # Recursively get valid path from source to destination and add paths to `all_paths`

    visited[source_ind...] = true
	push!(path, loc_ind2id(source_ind, p))

    if (source_ind === destination_ind)
		# If reached destination, then add to `all_paths`
		push!(all_paths, copy(path))
	else
		# Go to left, right, top and bottom grid locations recursively
		left = (source_ind[1] - 1, source_ind[2])
		right = (source_ind[1] + 1, source_ind[2])
		top = (source_ind[1], source_ind[2] + 1)
		bottom = (source_ind[1], source_ind[2] - 1)

		for ind in [left, right, top, bottom]
			if is_valid_loc_ind(ind, p) && !visited[ind...] && (is_loc_ind_empty(ind, p) || ind === destination_ind)
				_get_all_paths_helper(ind, destination_ind, visited, path, all_paths, p)
			end
		end

	end

	pop!(path)
	visited[source_ind...] = false

end

function get_travel_path(start_loc::Location, end_loc::Location, p::Parameters)::Vector{Vector{Int64}}
	# Get a random path from start to end location going through empty locations
	
	# Get index of start and end locations in location_map i.e. from Int64 to (Int64, Int64)
	start_ind = loc_id2ind(start_loc.id, p)
	end_ind = loc_id2ind(end_loc.id, p)

	# Variable to store current path; initialize with 0s
	path = Vector{Int64}(undef, 0)

	# Variable to store list of all paths
	all_paths = Vector{Vector{Int64}}(undef, 0)
	
	# Boolean matrix to set which locations are already visited when calculating a particular path
	visited = fill(false, size(p.map))

	# Get all paths from start_loc to end_loc
	_get_all_paths_helper(start_ind, end_ind, visited, path, all_paths, p)

	return all_paths

end

function interpolate_steps!(old::NTuple{2,Float64}, new::NTuple{2,Float64}, new_loc::Location, n::Int64)::Array{NTuple{2,Float64}}

    interpolated_steps = []
	oldX, oldY = old
	newX, newY = new
	
	t0 = 1
	tn = n

	for i = t0:tn
		# calculate new interim positions by linear interpolation
		interimX = interpolate(oldX, newX, i, t0, tn) + random_in_range(-.1, .1, .001)
		interimY = interpolate(oldY, newY, i, t0, tn) + random_in_range(-.1, .1, .001)
		xy = (interimX, interimY)
		xy = clamp_in_loc(xy, new_loc)
		push!(interpolated_steps, xy)
	end

    return interpolated_steps

end

function clamp_in_loc(pos::NTuple{2,Float64}, loc::Location)::NTuple{2,Float64}
    return (clamp(pos[1], loc.x_min + E, loc.x_max - E), clamp(pos[2], loc.y_min + E, loc.y_max - E))
end

end