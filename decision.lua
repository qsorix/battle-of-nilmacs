Decision = {
    Direction = {
        NORTH = {dx=0, dy=1},
        SOUTH = {dx=0, dy=-1},
        EAST = {dx=1, dy=0},
        WEST = {dx=-1, dy=0}
    }
}

function Decision.Move(direction)
    return {"move", direction}
end

function Decision.Attack(target)
    return {"attack", target}
end

function Decision.Eat(target)
    return {"eat", target}
end

function Decision.Breed(energy_for_offspring)
    assert(energy_for_offspring)
    return {"breed", energy_for_offspring}
end

function Decision.Photosynthesis()
    return {"photosynthesis"}
end
