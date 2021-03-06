module DataCollectorMod

using Agents:ABM
using ..ParametersMod:Parameters,Person,is_alive, is_infected
using ..LocationMod

function capture(model::ABM)::Dict

    data = Dict()
    params = model.parameters::Parameters

    data["step"] = params.step
    data["day"] = params.day

    # Agents position
    positions = vcat(_map(model.agents, (agent) -> [agent.pos[1], agent.pos[2]]))
    # positions = transpose(hcat(positions...))
    data["positions"] = positions

    # Vaccine shots
    data["vaccination"] = _map(model.agents, (agent) -> agent.vaccine_shots)
    # Mask
    data["mask"] = _map(model.agents, (agent) -> agent.is_masked)

    # Infection status
    data["infection_status"] = _map(model.agents, (agent) -> string(agent.infection_status))

    # Locations
    data["home_loc_id"] = _map(model.agents, (agent) -> agent.home_loc_id)
    data["current_loc_id"] = _map(model.agents, (agent) -> LocationMod.location_by_pos(agent.pos, params).id)

    # Counts
    data["count"] = Dict{Symbol,Int64}()
    for (_, agent::Person) in model.agents
        data["count"][agent.infection_status] = get(data["count"], agent.infection_status, 0) + 1
    end

    # stats
    data["stats"] = Dict()
    data["stats"]["total_dead"] = count(!is_alive(agent) for (_, agent) in model.agents)
    data["stats"]["total_infected"] = count(is_infected(agent) for (_, agent) in model.agents)

    return data

end

function _map(agent_dict::Dict, f::Any)::Array
    return [f(agent) for (_, agent::Person) in agent_dict]
end

end