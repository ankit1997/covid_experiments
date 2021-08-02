module UtilsMod

export is_probable, distance, random_in_range, interpolate

# +(a::NTuple{2,Float64},b::NTuple{2,Float64}) = (a[1]+b[1], a[2]+b[2])
# -(a::NTuple{2,Float64},b::NTuple{2,Float64}) = (a[1]-b[1], a[2]-b[2])
# /(a::NTuple{2,Float64},b::NTuple{2,Float64}) = (a[1]/b[1], a[2]/b[2])
# /(a::NTuple{2,Float64},b::Float64) = (a[1]/b, a[2]/b)
# *(a::NTuple{2,Float64},b::Float64) = (a[1]*b, a[2]*b)

function is_probable(prob::Float64)::Bool
    return rand() < prob
end

function distance(p1::NTuple{2,Float64}, p2::NTuple{2,Float64})
    return sqrt((p1[1] - p2[1])^2 + (p1[2] - p2[2])^2)
end

function random_in_range(m::Float64, M::Float64, step::Float64=.001)::Float64
    return rand(m:step:M)
end

function interpolate(old::Float64, new::Float64, t::Int64, t0::Int64, tn::Int64)::Float64
    return (tn == t0) ? new : (((tn - t) * old + (t - t0) * new) / (tn - t0))
end

end