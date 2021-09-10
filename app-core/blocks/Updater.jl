module UpdaterBlock

using Agents:ABM,add_agent!
using JSON
using Random

using ..PersonModule
using ..ModelUtilsModule:quarantine
using ..LocationModule

export enrich_params!, add_extra_agents!

function enrich_params!(model::ABM, attrs::Dict)
    parameters = model.parameters
    updated = Dict()

    _update_param_field(model, :infection_radius, attrs["infection_radius"], updated)
    _update_param_field(model, :social_distancing, attrs["social_distancing"], updated)
    _update_param_field(model, :step_size, attrs["step_size"], updated)
    if _update_param_field(model, :quarantine, attrs["quarantine"] / 100.0, updated)
        quarantine(model)
    end
    _update_param_field(model, :isolation, attrs["isolation"] / 100.0, updated)
    
    # parameters.infection_radius = get(attrs, "infection_radius", parameters.infection_radius)
    # parameters.prob_visit_hospital = get(attrs, "prob_visit_hospital", parameters.prob_visit_hospital)
    # parameters.prob_vaccinated_and_spread = get(attrs, "prob_vaccinated_and_spread", Tuple(parameters.prob_vaccinated_and_spread))
    # parameters.social_distancing = get(attrs, "social_distancing", parameters.social_distancing)
    # parameters.step_size = get(attrs, "step_size", parameters.step_size)
    

    percentage_masked = Float64(get(attrs, "percentage_masked", parameters.percentage_masked))
    _update_masked_agents!(model, percentage_masked, updated)

    percentage_vaccinated = get(attrs, "percentage_vaccinated", parameters.percentage_vaccinated)
    percentage_vaccinated = float.(percentage_vaccinated)
    _update_vaccinated_agents!(model, percentage_vaccinated, updated)

    updated["step"] = parameters.step
    if length(updated) == 1
        return
    end
    fname = "output/" * parameters.name * ".updates"
    if !isfile(fname)
		if !isdir("output")
			mkdir("output")
		end
		touch(fname)
	end
	open(fname, "a") do io
		write(io, JSON.json(updated) * "\n")
	end

end

function add_extra_agents!(model::ABM, n::Int64, status::String)
	empty = [loc for loc in model.parameters.Locations if loc.type === EMPTY]
	for _ = 1:n
		home = rand(empty)
		pos = random_pos_in_loc(home)
		add_agent!(pos, model, home.id, [], Symbol(status), 0, false, 0, rand(), false, false)
	end
	println(n, " agents added at step: ", model.parameters.step)
end

function _update_param_field(model::ABM, param::Symbol, new_value::Any, updateDict::Dict)::Bool
    old_value = getfield(model.parameters, param)
    if old_value != new_value
        setfield!(model.parameters, param, new_value)
        updateDict[string(param)] = Dict("old" => old_value, "new" => new_value)
        return true
    end
    return false
end

function _update_param(model::ABM, param::Symbol, updateDict::Dict)
    getfield(model.parameters, param)
end

function _update_masked_agents!(model::ABM, percentage_masked::Float64,  updateDict::Dict)
    # Mask or unmask agents in the model based on the `percentage_masked` parameter which defines the percentage of 
    # alive agents who are masked at any time.
    
    n_total = 0
    masked = []
    unmasked = []

    for (_, agent::Person) in model.agents
        agent.infection_status === DECEASED && continue
        n_total += 1
        push!(agent.is_masked ? masked : unmasked, agent.id)
    end

    num_masked_expected = clamp(floor(Int64, (percentage_masked / 100.0) * n_total), 1, n_total)

    if length(masked) < num_masked_expected
        num_to_be_masked = min(num_masked_expected - length(masked), length(unmasked))
        Random.shuffle!(unmasked)
        for i = 1:num_to_be_masked
            model.agents[unmasked[i]].is_masked = true
        end
        println(length(masked), " agents were already masked")
        println(num_to_be_masked, " more agents were masked just now")
        _update_param_field(model, :percentage_masked, percentage_masked, updateDict)
    elseif num_masked_expected < length(masked)
        num_to_be_unmasked = length(masked) - num_masked_expected
        Random.shuffle!(masked)
        for i = 1:num_to_be_unmasked
            model.agents[masked[i]].is_masked = false
        end
        println(length(masked), " agents were already masked")
        println(num_to_be_unmasked, " agents were un-masked just now")
        _update_param_field(model, :percentage_masked, percentage_masked, updateDict)
    end

end

function _update_vaccinated_agents!(model::ABM, percentage_vaccinated::Vector{Float64}, updateDict::Dict)
    # Vaccinate agents based on `percentage_vaccinated` parameter which defines the percentage of population which should get vaccinated in total

    n_total = 0
    vaccinated0 = []
    vaccinated1 = []
    vaccinated2 = []
        
    for (_, agent::Person) in model.agents
        agent.infection_status === DECEASED && continue
        n_total += 1
        n_shots = agent.vaccine_shots
        push!(n_shots === 0 ? vaccinated0 : n_shots === 1 ? vaccinated1 : vaccinated2, agent.id)
    end

    num_vaccine1_expected = clamp(floor(Int64, (percentage_vaccinated[1] / 100.0) * n_total), 0, n_total)
    num_vaccine2_expected = clamp(floor(Int64, (percentage_vaccinated[2] / 100.0) * n_total), 0, n_total)

    updated = false
    if length(vaccinated1) < num_vaccine1_expected
        num_to_be_vaccinated1 = min(num_vaccine1_expected - length(vaccinated1), length(vaccinated0))
        Random.shuffle!(vaccinated0)
        for i = 1:num_to_be_vaccinated1
            model.agents[vaccinated0[i]].vaccine_shots = 1
        end
        println(length(vaccinated1), " agents were already vaccinated with 1st dose")
        println(num_to_be_vaccinated1, " more agents were vaccinated with 1st dose just now")
        updated = true
    end
    
    if length(vaccinated2) < num_vaccine2_expected
        num_to_be_vaccinated2 = min(num_vaccine2_expected - length(vaccinated2), length(vaccinated1))
        Random.shuffle!(vaccinated1)
        for i = 1:num_to_be_vaccinated2
            model.agents[vaccinated1[i]].vaccine_shots = 2
        end
        println(length(vaccinated2), " agents were already vaccinated with 2nd dose")
        println(num_to_be_vaccinated2, " more agents were vaccinated with 2nd dose just now")
        updated = true
    end

    _update_param_field(model, :percentage_vaccinated, percentage_vaccinated, updateDict)

end

end