local species = {}
species.name = "bars"
species.display_letter = 'b'
species.display_color = 'blue'
species.initial_energy = 29

function species.brain()
    local dx, dy

    if Self.energy > 40 then
        return Decision.Breed(20)
    end

    local sees = Action.Look(2)
    if Self.energy < 5 or #sees > 11 then
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
