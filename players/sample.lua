-- Let's define the species of your creatures
local species = {}

-- The name will be used only to print scores and for some debug info. There
-- can't be two creatures with the same name, so ideally use your login.
species.name = "sample"

-- This lets you pick how your creatures will be drawn on the board. Available
-- colors include red, green, yellow, blue, magenta, cyan and white.
species.display_letter = 's'
species.display_color = 'white'

-- Initial energy is... The initial energy (sic!) your creatures will have at
-- the beginning of the simulation. It affects only the first creatures that are
-- there when the game starts. Later on, when breeding creature can decide how
-- much energy new creatures will get. See below for details.
-- 
-- Note that the energy poll available to you is limited, and engine will add
-- creatures as long as it's not empty. So the smaller you set this, the more
-- creatures there will be at the start, and vice-versa.
species.initial_energy = 400

-- This is the main function of your AI. It is called every time your creature
-- becomes active (i.e. it finishes its last action). As a result, you must
-- return a decision what to do next.
--
-- Inside this function, a global variable Self refers to the creature being
-- invoked. Thanks to it, creature is self-aware.
--
-- Some things creature may want to know about itself are its energy (Self.energy)
-- and position (Self.x, Self.y). Read the code of the engine to figure out what
-- else is there.
--
-- Creatures can also remember things. To do that, there's a special table
-- available for you at Self.memory. Use it in whatever fashion you want.
-- Initially it's empty.
function species.brain()

    -- You can figure out what's going on around you by looking. In return
    -- you'll return a list of creatures in selected range. The further you
    -- look, the more energy it costs.
    local sees = Action.Look(3)

    local choice = math.random(1, 4)

    -- You can try eating things to gain energy. Another creature must be dead
    -- to be eaten.
    -- Creature must be close to you to be eaten, you should find out by
    -- yourself how close is enough.
    --
    -- Eating is important because your score increases by the amount of energy
    -- gained.
    if choice == 1 then
        if #sees > 0 and
           Self.x == sees[1].x and
           Self.y == sees[1].y and
           not sees[1].alive then
            return Decision.Eat(sees[1])
        end
    end

    -- If you can't find a dead creature, try killing one that's alive.
    -- Once again, you must be close to your prey to kill it, but it's not
    -- checked here.
    if choice == 2 then
        if #sees > 0 and
           sees[1].alive then
            return Decision.Attack(sees[1])
        end
    end

    -- A proven way of surviving in a long run is having lots of offspring.
    -- Breeding an offspring will take some of your energy and use it as a
    -- starting energy for the offspring. It also uses some extra energy, so
    -- after breeding, the two creatures have less energy than one had before.
    --
    -- It's up to you to decide how much to gather before breeding, and how much
    -- to give to the offspring. Remember that a creature dies when its energy
    -- drops to zero.
    --
    -- Bred creatures start with no memory. They also don't know who their
    -- parent is. It's a tough world.
    if choice == 3 then
        if Self.energy > 100 then
            return Decision.Breed(10)
        end
    end

    -- Finally, you can move. There are some constants that may make it easier
    -- for you, but there's no need to use them.
    if choice == 4 then
        local moves = {NORTH, SOUTH, EAST, WEST}
        return Decision.Move(moves[math.random(#moves)])
    end

    -- Read the engine's code to see if there's something else...
end

--
-- Don't forget this! You must return the definition of your species.
--
return species
