module TransmissionBlock

using Agents:ABM,interacting_pairs
using ..PersonModule
using ..ParametersModule:pos2loc
using ..LocationModule
using ..ModelUtilsModule:change_infection_status!
using ..CommonUtilsModule

export transmission!

function transmission!(model::ABM)
    for (a1, a2) in interacting_pairs(model, model.parameters.infection_radius, :nearest)
        DECEASED in (a1.infection_status, a2.infection_status) && continue
        _transmit!(a1, a2, model)
    end
end

function _transmit!(a1::Person, a2::Person, model::ABM)

	params = model.parameters

    count(is_infected(a) for a in (a1, a2)) != 1 && return
    infected, healthy = is_infected(a1) ? (a1, a2) : (a2, a1)
	prob_infection_spread = prob_of_spread(infected, healthy, params.prob_vaccinated_and_spread)

    loc1 = pos2loc(a1.pos, params)
    loc2 = pos2loc(a2.pos, params)

	(loc1.type === ISOLATION || loc2.type === ISOLATION) && return

	can_interact = loc1.id === loc2.id || (loc1.type === loc2.type === EMPTY)

	if is_probable(prob_infection_spread) && can_interact
		if infected.is_asymptomatic
			change_infection_status!(healthy, model, ASYMPTOMATIC)
		else
			change_infection_status!(healthy, model, MILD)
		end
	end

end

end