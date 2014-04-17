local species = {}
species.name = "dumb"
species.display_letter = 'd'
species.display_color = 'cyan'
species.initial_energy = 1000

function species.brain()
    local moves = {NORTH, SOUTH, EAST, WEST}
    return Decision.Move(moves[math.random(#moves)])
end

return species
