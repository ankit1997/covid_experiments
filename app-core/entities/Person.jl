module PersonModule

export Person,any_status,distance,is_infected,prob_of_spread,SUSCEPTIBLE,ASYMPTOMATIC,MILD,INFECTED,SEVERE,HOSPITALIZED,RECOVERED,DECEASED

using Agents:AbstractAgent

SUSCEPTIBLE = :SUSCEPTIBLE
ASYMPTOMATIC = :ASYMPTOMATIC
MILD = :MILD
INFECTED = :INFECTED
SEVERE = :SEVERE
HOSPITALIZED = :HOSPITALIZED
RECOVERED = :RECOVERED
DECEASED = :DECEASED

mutable struct Person <: AbstractAgent
	id::Int64
	pos::NTuple{2,Float64}
	home_loc_id::Int64
	upcoming_pos::Array{NTuple{2,Float64}}
	infection_status::Symbol
	infection_status_duration::Int64
	is_masked::Bool
	vaccine_shots::Int64
	immunity::Float64
	is_asymptomatic::Bool
	is_home_quarantine::Bool
end

function any_status(person::Person, status_list::Array{Symbol})::Bool
    Base.any([person.infection_status === status for status in status_list])
end

function distance(p1::Person, p2::Person)::Float64
    x1, y1 = p1.pos
    x2, y2 = p2.pos
    √((x1 - x2)^2 + (y1 - y2)^2)
end

function is_infected(person::Person)::Bool
    any_status(person, [ASYMPTOMATIC, MILD, INFECTED, SEVERE, HOSPITALIZED])
end

function prob_of_spread(infected::Person, healthy::Person, prob_vaccinated_and_spread::NTuple{2,Float64})::Float64
	# Get probability of infection spread between a infected and a healthy agent given they interact in close enough proximity

    (infected.is_masked || healthy.is_masked) && return 0.0001

	if healthy.vaccine_shots > 0
		return prob_vaccinated_and_spread[healthy.vaccine_shots]
	end

	return 1.0 - healthy.immunity

end

end