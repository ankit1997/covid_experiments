module SocialDistancingBlock

using Agents:ABM,nearby_ids,move_agent!
using ..PersonModule
using ..ParametersModule
using ..ModelUtilsModule

export social_distancing!

function social_distancing!(agent::Person, model::ABM)
    
    model.parameters.social_distancing == 0 && return

    loc = pos2loc(agent.pos, model.parameters)
    dx = 0.0
    dy = 0.0
    for nearby_id in nearby_ids(agent.pos, model, model.parameters.infection_radius)
        nearby = model[nearby_id]
        dx += (agent.pos[1] - nearby.pos[1])
        dy += (agent.pos[2] - nearby.pos[2])
    end
    dx === 0.0 && dy === 0.0 && return

    d = √(dx^2 + dy^2)
    dx = 0.02 * model.parameters.social_distancing * (dx / d)
    dy = 0.02 * model.parameters.social_distancing * (dy / d)

    pos = clamp_in_loc((agent.pos[1] + dx, agent.pos[2] + dy), loc)
    move_agent!(agent, pos, model)

end

end