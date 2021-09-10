module DataCollectBlock

using Agents:ABM
using ..ParametersModule:Parameters,pos2loc
using ..PersonModule

export collector



function collector(model::ABM)::Dict

    data = Dict()
    params = model.parameters::Parameters

    data["step"] = params.step
    data["day"] = params.day

    # Agents position
    positions = vcat(_map(model, (agent) -> [agent.pos[1], agent.pos[2]]))
    # positions = transpose(hcat(positions...))
    data["positions"] = positions

    # Vaccine shots
    data["vaccination"] = _map(model, (agent) -> agent.vaccine_shots)
    # Mask
    data["mask"] = _map(model, (agent) -> agent.is_masked)

    # Infection status
    data["infection_status"] = _map(model, (agent) -> string(agent.infection_status))

    # Locations
    data["home_loc_id"] = _map(model, (agent) -> agent.home_loc_id)
    data["current_loc_id"] = _map(model, (agent) -> pos2loc(agent.pos, params).id)
    
    # Counts
    data["count"] = Dict{Symbol,Int64}()
    for (_, agent::Person) in model.agents
        data["count"][agent.infection_status] = get(data["count"], agent.infection_status, 0) + 1
    end

    # stats
    data["stats"] = Dict()
    data["stats"]["total_alive"] = count(agent.infection_status !== DECEASED for (_, agent) in model.agents)
    data["stats"]["total_dead"] = length(model.agents) - data["stats"]["total_alive"]
    data["stats"]["total_infected"] = count(is_infected(agent) for (_, agent) in model.agents)

    return data

end

function _map(model::ABM, f::Any)::Array
    n = length(model.agents)
    return [f(model[i]) for i in 1:n]
end

end