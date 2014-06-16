require "decision"
require "algorithms"
TQ = require "turn_queue"

local function size(table)
    local count = 0
    for a, b in pairs(table) do
        count = count + 1
    end
    return count
end

local function readonlytable(table)
   return setmetatable({}, {
     __index = table,
     __newindex = function(table, key, value)
                    error("Attempt to modify read-only table")
                  end,
     __metatable = false
   });
end

local function sort_set_of_creatures(set)
    local array = {}
    for c in pairs(set) do
        table.insert(array, c)
    end
    table.sort(array, function(a, b) return a.priority < b.priority end)
    return array
end

local _color_map = {
    red    = {'\27[1;31m', '\27[0;31m'},
    green  = {'\27[1;32m', '\27[0;32m'},
    yellow = {'\27[1;33m', '\27[0;33m'},
    blue   = {'\27[1;34m', '\27[0;34m'},
    magenta= {'\27[1;35m', '\27[0;35m'},
    cyan   = {'\27[1;36m', '\27[0;36m'},
    white  = {'\27[1;37m', '\27[0;37m'}
}

local function compute_display(letter, letter_dead, color)
    letter = letter or 'a'
    letter_dead = letter_dead or '%'
    local reset = '\27[0m'
    local c = _color_map[color] or {'', ''}
    return c[1] .. letter .. reset, c[2] .. letter_dead .. reset
end

Creature = {}
Creature.__index = Creature
function Creature:new()
    local o = {}
    setmetatable(o, self)
    return o
end

Game = {}
Game.__index = Game

function Game:new()
    local o = {
        creatures = {},
        -- creatures_safe keeps 'safe' read-only views on creatures, that are
        -- used inside brains. the purpose of this table is map from safe, back
        -- to normal creature tables
        -- The actual 'safe' view is part of the creature, and creatures are
        -- gathered in the creatures table, so here I go fully-weak.
        creatures_safe = {__mode='kv'},

        activation_queue = {},
        size = {},
        species_scores = {},
        turn_number = 0,
        turn_active_creatures = 0,

        initial_energy_pool = 50,
        energy_cost_breeding = 5,
        breed_distance = 2,
        attack_radius = 2,
        action_turn_cost = {
            move = 2,
            photosynthesis = 20,
            eat = 5,
        },
        turn_energy_cost = -1,
        turn_decompose_speed = -1,
        photosynthesis_energy_gain = 3.7
    }

    setmetatable(o, self)
    o:set_size(10, 10)
    return o
end

function Game:create_sandbox()
    return {
        pairs = pairs,
        ipairs = ipairs,
        table = {insert = table.insert,
                 remove = table.remove},
        math  = {sqrt = math.sqrt,
                 random = math.random,
                 abs = math.abs},

        Algo  = {closest = algorithms.closest,
                 closest_alive = algorithms.closest_alive,
                 closer_to = algorithms.closer_to,
                 away_from = algorithms.away_from},

        Decision = Decision,
        World = { X = self.size.x, Y = self.size.y },

        NORTH = Decision.Direction.NORTH,
        SOUTH = Decision.Direction.SOUTH,
        EAST = Decision.Direction.EAST,
        WEST = Decision.Direction.WEST,
    }
end

function Game:set_size(x, y)
    self.size.x = x
    self.size.y = y
    self.grid = {}
    self.count_by_species = {}
    for i = 1,x do
        self.grid[i] = {}
        for j = 1,y do
            self.grid[i][j] = {}
        end
    end
end

function Game:set_initial_energy(energy)
    self.initial_energy_pool = energy
end

function Game:draw()
    local BG = "\27[2;37m.\27[0m";

    local result = {}
    -- result = result .. ("\27[2J");
    table.insert(result, "\27[?25l"); -- hide cursor
    table.insert(result, "\27[1;1H");
    for y=self.size.y,1,-1 do
        for x=1,self.size.x,1 do
            local mark
            for c in pairs(self.grid[x][y]) do
                if not c.plant or not mark then
                    if c.alive then
                        mark = c.color or '@'
                    else
                        mark = c.color_dead or '%'
                    end
                end
            end
            table.insert(result, mark or BG)
        end
        table.insert(result, "\n");
    end
    table.insert(result, "\27[?25h"); -- show cursor
    table.insert(result, "\27[0J");
    io.write(table.concat(result, ""))

    print("\nTurn: " .. self.turn_number .. " Active: " .. self.turn_active_creatures .. " TQ: " .. size(self.activation_queue))


    ---[[
    local species_count = {}
    local species_energy = {}
    local species_energy_min = {}
    local species_energy_max = {}

    for c in pairs(self.creatures) do
        if c.alive then
            species_count[c.species] = (species_count[c.species] or 0) + 1
            species_energy[c.species] = (species_energy[c.species] or 0) + c.energy
            species_energy_min[c.species] = math.min(species_energy_min[c.species] or 1000000000, c.energy)
            species_energy_max[c.species] = math.max(species_energy_max[c.species] or 0, c.energy)
        end
    end

    print("")
    print("Stats:             Score  Count    Min E   Avg E   Max E")
    for c in pairs(species_count) do
        io.write(string.format(
            "%-10s  %12i  %5i  %7.1f %7.1f %7.1f\n",
            c,
            math.floor(self.species_scores[c] or 0),
            species_count[c],
            species_energy_min[c],
            math.floor(species_energy[c]/species_count[c]),
            species_energy_max[c]))
    end
    --]]
end

function Game:add_species(species)
    local energy_left = self.initial_energy_pool
    local species_initial_energy = species.initial_energy or 20
    while energy_left > 0 do
        local energy
        if energy_left > species_initial_energy then
            energy = species_initial_energy
        else
            energy = energy_left
        end
        energy_left = energy_left - energy
        local dsp_alive, dsp_dead = compute_display(species.display_letter,
                                                    species.display_letter_dead,
                                                    species.display_color)
        self:add_creature(species.brain, species.name, dsp_alive, dsp_dead, energy, species.plant)
    end
    for i = 1,20 do
    end
end

function Game:count_creatures_of_species(species_name)
    return self.count_by_species[species_name] or 0
end

function Game:count_living_creatures_of_species(species_name)
    local count = 0
    for c in pairs(self.creatures) do
        if c.alive and c.species == species_name then
            count = count + 1
        end
    end
    return count
end

function Game:count_creatures()
    local count = 0
    for c in pairs(self.creatures) do
        if c.alive then
            count = count + 1
        end
    end
    return count
end

function Game:living_species()
    local species = {}
    local living = 0
    for c in pairs(self.creatures) do
        if c.alive then
            if not species[c.species] then
                living = living + 1
                species[c.species] = true
            end
        end
    end
    return living
end


function Game:create_creature(brain, species, color, color_dead, initial_energy, plant)
    assert(type(brain)=="function", "creatures must be functions")
    local c = Creature:new()
    c.priority = math.random()
    c.brain = brain
    c.species = species or "cat"
    c.x = math.random(1, self.size.x)
    c.y = math.random(1, self.size.y)
    c.energy = initial_energy or 20
    c.flesh = c.energy
    c.alive = true
    c.color = color or "x"
    c.color_dead = color_dead or "x"
    c.memory = {}
    c.safe = readonlytable(c)
    c.plant = plant

    local env = {
        Action = {
            Look = function(power) return self:creature_look(c, power) end,
        },
        Self = c.safe
    }
    setmetatable(env, {__index = self:create_sandbox()})

    c.env = env
    return c
end

function Game:add_creature(brain, species, color, color_dead, initial_energy, plant)
    local c = self:create_creature(brain, species, color, color_dead, initial_energy, plant)

    self.creatures[c] = true
    self.creatures_safe[c.safe] = c
    self.count_by_species[c.species] = (self.count_by_species[c.species] or 0) + 1
    TQ.enqueue(self.activation_queue, c, (self.turn_number+1))

    self:put_on_grid(c)

    return c
end

function Game:adjust_to_grid(x, y)
    x = math.max(1, math.min(self.size.x, x))
    y = math.max(1, math.min(self.size.y, y))
    return x, y
end

function Game:put_on_grid(creature)
    self.grid[creature.x][creature.y][creature] = true
end

function Game:remove_from_grid(creature)
    self.grid[creature.x][creature.y][creature] = nil
end

function Game:move_on_grid(creature, x, y)
    self:remove_from_grid(creature)
    creature.x = x
    creature.y = y
    self:put_on_grid(creature)
end

-- TODO(qsorix): Used only in tests. Remove/replace
function Game:add_creature_at_position(brain, x, y)
    local c = self:add_creature(brain)
    self:move_on_grid(c, x, y)
    return c
end

function Game:remove_creature(c)
    self:remove_from_grid(c)
    self.creatures[c] = nil
    self.count_by_species[c.species] = self.count_by_species[c.species] - 1
    c.purge = true
end

function Game:finished()
    if self:living_species() > 1 then
        return false
    end
    return true
end

function Game:turn()
    local creatures, activation_turn = TQ.dequeue(self.activation_queue, self.turn_number)
    self.turn_number = activation_turn

    -- sorting is done to make iteration's order deterministic. This way I can
    -- replay the whole game by setting the same randomseed.
    creatures = sort_set_of_creatures(creatures)

    -- for debug/performance analysis
    self.turn_active_creatures = #creatures

    for _, creature in ipairs(creatures) do
        local next_activation = activation_turn+1

        if creature.purge then
            -- pass
        elseif creature.alive then
            local decision = self:creature_run_brain(creature)

            if decision then
                local time_cost = self:creature_run_decision(creature, decision)

                next_activation = activation_turn + time_cost
            else
                -- no decision -> creature is dead now
            end
        else
            -- "decompose" dead stuff
            self:creature_decompose(creature)
        end

        if not creature.purge then
            TQ.enqueue(self.activation_queue, creature, next_activation)
        end
    end
end

function Game:species_add_points(species, points)
    self.species_scores[species] = (self.species_scores[species] or 0) + points
end

function Game:species_score(species)
    return self.species_scores[species] or 0
end

function Game:adjust_creature_energy(creature, delta, no_score)
    creature.energy = creature.energy + delta

    if delta > 0 and not no_score then
        self:species_add_points(creature.species, delta)
    end

    if (creature.energy <= 0) then
        creature.alive = false
    end
end

function Game:is_alive(creature)
    return creature.alive
end

function Game:can_creature_see(observer, creature, power)
    local dx = observer.x-creature.x
    local dy = observer.y-creature.y
    return dx^2 + dy^2 <= power^2
end

function Game:creature_run_brain(creature)
    setfenv(creature.brain, creature.env)

    -- pcal returns either (true, decision) or (false, errmsg)
    local status, result = pcall(creature.brain)

    if status then
        if not result or type(result) ~= "table" then
            return {"noop"}
        end
        return result
    else
        -- kill creatures with code causing errors
        creature.alive = false

        if self.panic_on_errors then
            error(result)
        end
        if self.print_errors then
            io.stderr:write(result)
        end
    end
end

function Game:creature_run_decision(creature, decision)
    if decision[1] == "move" then
        self:creature_move(creature, decision[2])
    elseif decision[1] == "attack" then
        self:creature_attack(creature, decision[2])
    elseif decision[1] == "eat" then
        self:creature_eat(creature, decision[2])
    elseif decision[1] == "breed" then
        self:creature_breed(creature, decision[2])
    elseif decision[1] == "photosynthesis" then
        self:creature_photosynthesis(creature)
    end

    self:adjust_creature_energy(creature, self.turn_energy_cost)

    return self.action_turn_cost[decision[1]] or 1
end

function Game:creature_move(creature, move)
    if not creature.plant then
        local x, y = self:adjust_to_grid(creature.x + move.dx, creature.y + move.dy)
        self:move_on_grid(creature, x, y)
    else
        --[[
        io.stderr:write("Creature " .. creature.species  .. " tries to lose roots\n")
        --]]
        creature.alive = false
    end
end

function Game:creature_look(creature, power)
    local result = {}

    local xmin = math.max(creature.x-power, 1)
    local xmax = math.min(creature.x+power, self.size.x)
    local ymin = math.max(creature.y-power, 1)
    local ymax = math.min(creature.y+power, self.size.y)
    for x = xmin, xmax do
        for y = ymin, ymax do
            if ((creature.x-x)*(creature.x-x) + (creature.y-y)*(creature.y-y) <= power*power) then
                for p in pairs(self.grid[x][y]) do
                    if p ~= creature then
                        table.insert(result, p.safe)
                    end
                end
            end
        end
    end
    return result
end

function Game:creature_attack(attacker, prey)
    assert(attacker)
    assert(prey)
    if self:can_creature_see(attacker, prey, self.attack_radius) then
        assert(self.creatures_safe[prey])
        self.creatures_safe[prey].alive = false
    end
end

function Game:creature_eat(attacker, prey)
    assert(attacker)
    assert(prey)
    if not prey.alive then
        prey = self.creatures_safe[prey]
        self:adjust_creature_energy(attacker, prey.flesh, attacker.species == prey.species)
        self:remove_creature(prey)
    end
end

function Game:creature_photosynthesis(creature)
    if creature.plant then
        self:adjust_creature_energy(creature, self.photosynthesis_energy_gain)
    else
        creature.alive = false
        --[[
        io.stderr:write("Creature " .. creature.species  .. " tries to be green\n")
        --]]
    end
end

function Game:creature_breed(breeder, energy_for_offspring)
    local cost = self.energy_cost_breeding + energy_for_offspring

    if breeder.energy < cost then
        --[[
        io.stderr:write("Creature " .. breeder.species ..
                        " tries to breed without energy. Has: " ..
                        breeder.energy .. ", requires: " .. 
                        cost .. "\n")
        --]]
        return nil
    end

    self:adjust_creature_energy(breeder, -cost)

    local new_creature =  self:add_creature(breeder.brain, breeder.species, breeder.color, breeder.color_dead, energy_for_offspring, breeder.plant)

    local x=breeder.x
    local y=breeder.y
    while x==breeder.x and y==breeder.y do
        local dx = math.random(-self.breed_distance, self.breed_distance)
        local dy = math.random(-self.breed_distance, self.breed_distance)
        x, y = self:adjust_to_grid(breeder.x+dx, breeder.y+dy)
    end

    self:move_on_grid(new_creature, x, y)

    return new_creature
end

function Game:creature_decompose(creature)
    creature.flesh = creature.flesh + self.turn_decompose_speed
    if creature.flesh <= 0 then
        self:remove_creature(creature)
    end
end

return Game
