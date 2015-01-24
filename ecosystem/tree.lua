local species = {}
species.name = "tree"
species.display_letter = 'T'
species.display_letter_dead = 'T'
species.display_color = 'green'
species.initial_energy = 750
species.plant = true

function species.brain()
    if Self.energy > 1030 then
        return Decision.Breed(500+500*math.random())
    end

    -- prevents trees from growing too close to each other. if that happens, one
    -- tree will slowly die
    local sees = Action.Look(1)
    for _, c in ipairs(sees) do
        if c.species == species.name and
           c.priority > Self.priority then
            return nil
        end
    end

    return Decision.Photosynthesis()
end

return species
