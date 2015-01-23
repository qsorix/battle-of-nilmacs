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

local function sort_by_priority(array)
    table.sort(array, function(a, b) return a.priority < b.priority end)
end

local function sort_set_of_creatures(set)
    local array = {}
    for c in pairs(set) do
        table.insert(array, c)
    end
    sort_by_priority(array)
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

        species = {},

        activation_queue = {},
        size = {},

        stats = {
           count = {}, -- all creatures per species
           living = {}, -- living creatures per species
           scores = {}, -- score per species
        },
        turn_number = 0,
        turn_active_creatures = 0,

        initial_energy_pool = 50,
        energy_cost_breeding = 5,
        breed_distance = 2,
        attack_radius = 2,
        attack_success_ratio_exponent = 1.60,
        action_turn_cost = {
            move = 2,
            photosynthesis = 20,
            eat = 5,
        },
        turn_energy_cost = -1,
        turn_decompose_speed = -1,
        photosynthesis_energy_gain = 6.0,
        -- 25000 instructions per turn was maximum observed in submissions sent
        -- for the 1st round of the tournament
        executing_instruction_cost = (0.1 / 25000),
        executing_instruction_cost_incured_once_per_turns = 1000
    }

    setmetatable(o, self)
    o:set_size(10, 10)
    return o
end

function Game:create_sandbox()
    local visible_global

    if self.sandbox_includes_global_scope then
        visible_global = _G
    else
        visible_global = {
            pairs = pairs,
            ipairs = ipairs,
            table = {insert = table.insert,
                     remove = table.remove},
            math  = {sqrt = math.sqrt,
                     random = math.random,
                     abs = math.abs,
                     max = math.max,
                     min = math.min},
        }
    end

    local game_sandbox = {
        Algo  = {distance = algorithms.distance,
                 closest = algorithms.closest,
                 closest_alive = algorithms.closest_alive,
                 closer_to = algorithms.closer_to,
                 away_from = algorithms.away_from},

        Decision = Decision,
        World = {X = self.size.x,
                 Y = self.size.y,
                 SandboxDisabled = self.sandbox_includes_global_scope},

        NORTH = Decision.Direction.NORTH,
        SOUTH = Decision.Direction.SOUTH,
        EAST = Decision.Direction.EAST,
        WEST = Decision.Direction.WEST,
    }

    setmetatable(game_sandbox, {__index = visible_global})
    return game_sandbox
end

function Game:set_size(x, y)
    self.size.x = x
    self.size.y = y
    self.grid = {}
    self.plants_grid = {}
    for i = 1,x do
        self.grid[i] = {}
        self.plants_grid[i] = {}
        for j = 1,y do
            self.grid[i][j] = {}
            self.plants_grid[i][j] = 0
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
            local cell = self.grid[x][y]
            for i = 1, #cell do
                local c = cell[i]
                if not self:is_plant(c) or not mark then
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
    local species_energy = {}
    local species_energy_min = {}
    local species_energy_max = {}

    for c in pairs(self.creatures) do
        if c.alive then
            species_energy[c.species] = (species_energy[c.species] or 0) + c.energy
            species_energy_min[c.species] = math.min(species_energy_min[c.species] or 1000000000, c.energy)
            species_energy_max[c.species] = math.max(species_energy_max[c.species] or 0, c.energy)
        end
    end

    print("")
    print("Stats:             Score  Count    Min E   Avg E   Max E")
    for c in pairs(species_energy) do
        io.write(string.format(
            "%-10s  %12i  %5i  %7.1f %7.1f %7.1f\n",
            c,
            math.floor(self.stats.scores[c] or 0),
            self.stats.living[c],
            species_energy_min[c],
            math.floor(species_energy[c]/self.stats.living[c]),
            species_energy_max[c]))
    end
    --]]
end

function Game:add_species(species)
    local dsp_alive, dsp_dead = compute_display(species.display_letter,
                                                species.display_letter_dead,
                                                species.display_color)
    species._display_alive = dsp_alive
    species._display_dead = dsp_dead

    self.species[species.name] = species

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
        self:add_creature(species, energy)
    end
end

function Game:count_creatures_of_species(species_name)
    return self.stats.count[species_name] or 0
end

function Game:count_living_creatures_of_species(species_name)
    return self.stats.living[species_name] or 0
end

function Game:create_creature(species, initial_energy)
    local c = Creature:new()
    c.priority = math.random()
    c.brain = species.brain
    c.species = species.name
    c.color = species._display_alive
    c.color_dead = species._display_dead
    c.x = math.random(1, self.size.x)
    c.y = math.random(1, self.size.y)
    c.energy = initial_energy or 20
    c.flesh = c.energy
    c.alive = true
    c.memory = {}
    c.sees = {} -- optimization: avoids creating new tables to return results of
                -- creature_look
    c.safe = readonlytable(c)

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

function Game:add_creature(species, initial_energy)
    -- TODO(qsorix): This first part helps in tests. Move it to tests
    species.name = species.name or "species ("..tostring(species)..")"
    species.brain = species.brain or function() end

    if not self.species[species.name] then
        self.species[species.name] = species
    end
    --

    local c = self:create_creature(species, initial_energy)

    self.creatures[c] = true
    self.creatures_safe[c.safe] = c
    self.stats.count[c.species] = (self.stats.count[c.species] or 0) + 1
    self.stats.living[c.species] = (self.stats.living[c.species] or 0) + 1
    TQ.enqueue(self.activation_queue, c, (self.turn_number+1))

    self:put_on_grid(c)

    return c
end

function Game:adjust_to_grid(x, y)
    x = math.max(1, math.min(self.size.x, x))
    y = math.max(1, math.min(self.size.y, y))
    return x, y
end

function Game:adjust_plants_grid(x, y, delta)
    for i = math.max(1, x-1), math.min(self.size.x, x+1) do
        for j = math.max(1, y-1), math.min(self.size.y, y+1) do
            self.plants_grid[i][j] = self.plants_grid[i][j] + delta
        end
    end
    self.plants_grid[x][y] = self.plants_grid[x][y] + delta
end

function Game:put_on_grid(creature)
    if self:is_plant(creature) then
        self:adjust_plants_grid(creature.x, creature.y, 1)
    end
    table.insert(self.grid[creature.x][creature.y], creature)
end

function Game:remove_from_grid(creature)
    if self:is_plant(creature) then
        self:adjust_plants_grid(creature.x, creature.y, -1)
    end
    local cell = self.grid[creature.x][creature.y]
    for i = 1,#cell do
        if cell[i] == creature then
            table.remove(cell, i)
            return
        end
    end
end

function Game:move_on_grid(creature, x, y)
    self:remove_from_grid(creature)
    creature.x = x
    creature.y = y
    self:put_on_grid(creature)
end

-- TODO(qsorix): Used only in tests. Remove/replace
function Game:add_creature_at_position(species, x, y, species_name)
    local c = self:add_creature(species, species_name)
    self:move_on_grid(c, x, y)
    return c
end

function Game:remove_creature(c)
    self:remove_from_grid(c)
    self.creatures[c] = nil
    self.stats.count[c.species] = self.stats.count[c.species] - 1
    c.purge = true
end

function Game:kill_creature(c)
   if c.alive then
      c.alive = false
      self.stats.living[c.species] = self.stats.living[c.species] - 1
   end
end

function Game:finished()
    local living_species = 0
    for s in pairs(self.stats.living) do
        if self.stats.living[s] ~= 0 then
            living_species = living_species + 1
        end
    end
    return living_species <= 1
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
    self.stats.scores[species] = (self.stats.scores[species] or 0) + points
end

function Game:species_score(species)
    return self.stats.scores[species] or 0
end

function Game:adjust_creature_energy(creature, delta, no_score)
    creature.energy = creature.energy + delta

    if delta > 0 and not no_score then
        self:species_add_points(creature.species, delta)
    end

    if (creature.energy <= 0) then
        self:kill_creature(creature)
    end
end

function Game:is_alive(creature)
    return creature.alive
end

function Game:is_plant(creature)
    return self.species[creature.species].plant
end

function Game:can_creature_see(observer, creature, power)
    local dx = observer.x-creature.x
    local dy = observer.y-creature.y
    return dx^2 + dy^2 <= power^2
end

function Game:count_plants_close_to(creature)
    return self.plants_grid[creature.x][creature.y]
end

local function run_with_hook(func, hook, instructions)
    local status, result

    -- The inner pcall catches any error caused by `func`, plus errors raised
    -- from `hook` to interrupt execution of `func`.
    --
    -- When leaving inner pcall, the hook is still active, and can trigger
    -- before it's disabled. That's why there's the outer pcall. The second
    -- sethook is there to handle cases when the outer pcall was used.
    --
    -- This only works if the hook is not scheduled to run too often. And I feel
    -- like I've missed something simpler.
    local st2, err2 = pcall(function()
        debug.sethook(hook, "", instructions)

        status, result = pcall(func)

        debug.sethook()
    end)
    debug.sethook()

    -- if the outer pcall got called, it means the hook triggered and the error
    -- should be returned
    if not st2 then
        return st2, err2
    end

    return status, result
end

function Game:creature_run_brain(creature)
    setfenv(creature.brain, creature.env)

    local energy_exceeded = {} -- acts as a unique exception object

    local status, result

    local hook_cost =
        self.executing_instruction_cost_incured_once_per_turns *
        self.executing_instruction_cost

    local energy = creature.energy

    local function hook(event, line)
        energy = energy - hook_cost
        if energy <= 0 then
            energy = 0
            error(energy_exceeded)
        end
    end

    status, result = run_with_hook(creature.brain, hook, self.executing_instruction_cost_incured_once_per_turns)

    creature.energy = energy

    if status then
        if not result or type(result) ~= "table" then
            return {"noop"}
        end
        return result
    else
        -- kill creatures with code causing errors
        self:kill_creature(creature)

        if (result ~= energy_exceeded) then
            if self.print_errors then
                io.stderr:write(result)
            end
            if self.panic_on_errors then
                error(result)
            end
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
    if not self:is_plant(creature) then
        local x, y = self:adjust_to_grid(creature.x + move.dx, creature.y + move.dy)
        self:move_on_grid(creature, x, y)
    else
        --[[
        io.stderr:write("Creature " .. creature.species  .. " tries to lose roots\n")
        --]]
        self:kill_creature(creature)
    end
end

function Game:creature_look(creature, power)
    local result = creature.sees
    for i = 1, #result do
        result[i] = nil
    end

    local xmin = math.max(creature.x-power, 1)
    local xmax = math.min(creature.x+power, self.size.x)
    local ymin = math.max(creature.y-power, 1)
    local ymax = math.min(creature.y+power, self.size.y)
    for x = xmin, xmax do
        for y = ymin, ymax do
            if ((creature.x-x)*(creature.x-x) + (creature.y-y)*(creature.y-y) <= power*power) then
                for _, p in ipairs(self.grid[x][y]) do
                    if p ~= creature then
                        result[#result+1] = p.safe
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
        local ratio = attacker.flesh / prey.flesh
        if ratio < 1 and math.pow(ratio, self.attack_success_ratio_exponent) < math.random() then
            return
        end
        assert(self.creatures_safe[prey])
        self:kill_creature(self.creatures_safe[prey])
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
    if self:is_plant(creature) then
        local plants = self:count_plants_close_to(creature)
        if plants < 8 then
            plants = plants*0.1
        end
        self:adjust_creature_energy(creature, self.photosynthesis_energy_gain/(1+plants))
    else
        self:kill_creature(creature)
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

    local new_creature = self:add_creature(self.species[breeder.species], energy_for_offspring)

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
