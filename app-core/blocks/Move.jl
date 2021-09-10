module MoveBlock

using Agents:ABM,move_agent!
using ..PersonModule
using ..ParametersModule

export move_person!

function move_person!(agent::Person, model::ABM, next_pos::NTuple{2,Float64})

    current_loc = pos2loc(agent.pos, model.parameters)
    next_loc = pos2loc(next_pos, model.parameters)

	move_agent!(agent, next_pos, model)

	next_loc.capacity -= 1
	current_loc.capacity += 1

end

end