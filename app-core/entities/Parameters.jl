module ParametersModule

using ..LocationModule

export Parameters,loc_ind2id,loc_id2ind,is_valid_loc_ind,pos2loc

mutable struct Parameters

    name::String

    day::Int64
    step::Int64
    step_size::Int64
    stop_flag::Bool

    num_agents::Int64
    num_days::Int64
    num_steps_in_day::Int64

    infection_radius::Float64
    initial_infections::Int64

    world_width::Float64
    world_height::Float64
    loc_width::Float64
    loc_height::Float64
    Locations::Array{Location}
    map::Matrix{Symbol}
    map_item_capacity::Dict{Symbol,Int64}

    prob_visit_hospital::Dict{Symbol,Float64}

    prob_vaccinated_and_spread::NTuple{2,Float64}
    percentage_masked::Float64
    percentage_vaccinated::Array{Float64}

    social_distancing::Int64
    quarantine::Float64
    isolation::Float64

end

function loc_ind2id(ind::NTuple{2,Int64}, p::Parameters)::Int64
    ROWS, COLUMNS = size(p.map)
    return (ROWS - ind[1]) * COLUMNS + ind[2]
end

function loc_id2ind(id::Int64, p::Parameters)::NTuple{2,Int64}
    ROWS, COLUMNS = size(p.map)
    r = ROWS - floor(Int64, (id - 1) / COLUMNS)
    c = ((id - 1) % COLUMNS) + 1
    return (r, c)
end

function is_valid_loc_ind(ind::NTuple{2,Int64}, p::Parameters)
	ROWS, COLUMNS = size(p.map)
    (1 <= ind[1] <= ROWS && 1 <= ind[2] <= COLUMNS)
end

function pos2loc(pos::NTuple{2,Float64}, p::Parameters)

    x, y = pos
    (!(0.0 <= x <= p.world_width) || !(0.0 <= y <= p.world_height)) && return nothing

	rows, cols = size(p.map)
	col = max(ceil(Int64, x / p.loc_width), 1)
	row = rows + 1 - max(ceil(Int64, y / p.loc_height), 1)
	id = loc_ind2id((row, col), p)
	
	return p.Locations[id]

end

end