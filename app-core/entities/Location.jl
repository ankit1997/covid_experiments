module LocationModule

export Location, random_pos_in_loc, EMPTY, HOUSE, HOSPITAL, COMMON, ISOLATION

EMPTY = :O
HOUSE = :H
HOSPITAL = :+
COMMON = :C
ISOLATION = :Q

mutable struct Location
	id::Int64
	type::Symbol
	capacity::Int64
	x_min::Float64
	x_max::Float64
	y_min::Float64
	y_max::Float64
    social_distancing::Float64
    prob_move_in_same_loc::Float64
    prob_move_to_diff_loc::Float64
    prob_come_from_diff_loc::Float64
end

function random_pos_in_loc(loc::Location)::NTuple{2,Float64}
    return _random_in_range(loc.x_min, loc.x_max, 0.0001), _random_in_range(loc.y_min, loc.y_max, 0.0001)
end

_random_in_range(low::Float64, high::Float64, step::Float64) = rand(low:step:high)

end