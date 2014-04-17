local species = {}
species.name = "grass"
species.display_letter = '"'
species.display_letter_dead = '"'
species.display_color = 'green'
species.initial_energy = 5
species.plant = true

function species.brain()

    if Self.energy > 12 then
        local near = Action.Look(1)
        local count = 0
        for _, c in ipairs(near) do
            if c.species == "grass" then
                count = count + 1
            end
        end
        if count < 3 then
            return Decision.Breed(5)
        end
    end
    return Decision.Photosynthesis()
end

return species
