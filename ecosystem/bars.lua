local species = {}
species.name = "bars"
species.display_letter = 'b'
species.display_color = 'blue'
species.initial_energy = 29

local function count_grass(sees)
    local count = 0
    for _, c in ipairs(sees) do
        if c.species == "grass" then
            count = count + 1
        end
    end
    return count
end

function species.brain()
    local dx, dy

    if Self.energy > 40 then
        return Decision.Breed(29)
    end

    local sees = Action.Look(2)
    if count_grass(sees) > 2 then
        local dx, dy, c = Algo.closest("grass", Self, sees)
        if (c) then
            if c.alive then
                return Decision.Attack(c)
            else
                return Decision.Eat(c)
            end
        end
    end

    local sees = Action.Look(10)
    local dx, dy = Algo.closest_alive("foos", Self, sees)
    if (dx and dy) then
        return Decision.Move(Algo.away_from(dx, dy))
    end

    local moves = {NORTH, SOUTH, EAST, WEST}

    return Decision.Move(moves[math.random(#moves)])
end

return species
