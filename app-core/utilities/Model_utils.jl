module ModelUtilsModule

export change_infection_status!,clamp_in_loc,quarantine

using Agents:ABM
using ..PersonModule
using ..LocationModule
using ..ParametersModule:pos2loc
using Random:shuffle

function change_infection_status!(agent::Person, model::ABM, status::Symbol)

    agent.infection_status === status && return
    agent.infection_status = status
    agent.infection_status_duration = 0

    if any_status(agent, [HOSPITALIZED])
        empty!(agent.upcoming_pos)
    elseif any_status(agent, [DECEASED])
        empty!(agent.upcoming_pos)
        loc = pos2loc(agent.pos, model.parameters)
        loc.capacity += 1
    elseif any_status(agent, [RECOVERED])
        empty!(agent.upcoming_pos)
    end

end

function clamp_in_loc(pos::NTuple{2,Float64}, loc::Location)::NTuple{2,Float64}
    E = 0.0001
	return (clamp(pos[1], loc.x_min + E, loc.x_max - E), clamp(pos[2], loc.y_min + E, loc.y_max - E))
end

function quarantine(model::ABM)
    candidates = [agent for (_, agent::Person) in model.agents if any_status(agent, [INFECTED, SEVERE]) && agent.home_loc_id !== -1]
    n = length(candidates)
    num_quarantine = floor(Int64, model.parameters.quarantine * n)

    is_quarantined = shuffle([fill(false, n - num_quarantine); fill(true, num_quarantine)])
    for i = 1:n
        candidates[i].is_home_quarantine = is_quarantined[i]
    end
end

end