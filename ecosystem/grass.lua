local species = {}
species.name = "grass"
species.display_letter = '"'
species.display_letter_dead = '"'
species.display_color = 'green'
species.initial_energy = 5
species.plant = true

function species.brain()
    if Self.energy > 12 then
        return Decision.Breed(5)
    end
    return Decision.Photosynthesis()
end

return species
