require "lunit"
require "game"

module("test_game_actions", lunit.testcase, package.seeall)

function test_creatures_can_move()
    local function test_move(move, expected_dx, expected_dy)
        local brain = function()
            return Decision.Move(move)
        end

        local g = Game:new()
        g:set_size(10, 10)
        creature = g:add_creature_at_position({brain=brain}, 5, 5)

        local x, y = creature.x, creature.y
        g:turn()
        local xn, yn = creature.x, creature.y
        assert_true(xn-x == expected_dx)
        assert_true(yn-y == expected_dy)
    end
    test_move(Decision.Direction.NORTH,  0,  1)
    test_move(Decision.Direction.SOUTH,  0, -1)
    test_move(Decision.Direction.EAST,   1,  0)
    test_move(Decision.Direction.WEST,  -1,  0)
end

function test_creatures_cannot_move_beyond_the_grid()
    local function test_bad_move(move)
        local brain = function()
            return Decision.Move(move)
        end

        local g = Game:new()
        g:set_size(1, 1)
        creature = g:add_creature_at_position({brain=brain}, 1, 1)

        local x, y = creature.x, creature.y
        g:turn()
        local xn, yn = creature.x, creature.y
        assert_true(xn == x)
        assert_true(yn == y)
    end
    test_bad_move(Decision.Direction.NORTH)
    test_bad_move(Decision.Direction.SOUTH)
    test_bad_move(Decision.Direction.EAST)
    test_bad_move(Decision.Direction.WEST)
end

function test_creature_can_see_other_creatures()
    local seen
    local creature1 = function() seen = Action.Look(2) end
    local creature2 = function() end

    local g = Game:new()
    g:set_size(2,2)
    creature1 = g:add_creature({brain=creature1})
    creature2 = g:add_creature({brain=creature2})

    g:turn()

    assert_table(seen)
    assert_equal(seen[1], creature2.safe)
end

function test_creature_sees_only_near_creatures()
    local g = Game:new()
    g:set_size(20, 20)

    local seen
    local c1 = function() seen = Action.Look(5) end
    local c2 = function() end
    local c3 = function() end

    c1 = g:add_creature_at_position({brain=c1}, 5, 5)
    c2 = g:add_creature_at_position({brain=c2}, 6, 6)
    c3 = g:add_creature_at_position({brain=c3}, 20, 20)

    g:turn()

    assert_table(seen)
    assert_equal(#seen, 1)
end


function test_creature_can_move_and_kill()
    local moved = false

    local creature = function()
        local sees = Action.Look(5)
        if #sees > 0 then
            return Decision.Attack(sees[1])
        else
            moved = true
            return Decision.Move(NORTH)
        end
    end

    local prey = function() end

    local g = Game:new()
    g.attack_radius = 5
    g:set_size(10, 10)
    creature = g:add_creature_at_position({brain=creature}, 1, 1)
    prey = g:add_creature_at_position({brain=prey}, 1, 1+6)

    g:turn()
    assert_true(moved)
    assert_true(g:is_alive(prey))

    g:turn()
    g:turn()
    assert_false(g:is_alive(prey))
end

function test_creature_can_kill_another_creature()
    local g = Game:new()
    local c1 = g:add_creature_at_position({}, 1, 1)
    local c2 = g:add_creature_at_position({brain=function() return Decision.Attack(c1.safe) end}, 1, 2)

    g:turn()

    assert_false(g:is_alive(c1))
    assert_true(g:is_alive(c2))
end

function test_probability_of_a_successful_kill_depends_on_creatures_size()
    local g = Game:new()
    g.attack_success_ratio_exponent = 2

    local kills = 0
    local tries = 0

    for i = 1, 20 do
        local c1 = g:add_creature_at_position({}, 1, 2)
        local c2 = g:add_creature_at_position(
            {brain = function()
                 return Decision.Attack(c1.safe)
             end}, 1, 1)

        -- c2 is to small to kill c1 every time (probability = (1/2)^2)
        c1.flesh = 2
        c2.flesh = 1

        g:turn()

        tries = tries + 1
        if not g:is_alive(c1) then
            kills = kills + 1
        end
    end

    -- expected probabily is around 0.25
    local p = kills / tries
    assert_true (0.20 <= p and p <= 0.30)

end

function test_creature_can_attack_only_creatures_it_sees()
    local g = Game:new()

    -- FIXME attack_radius?
    local c1 = g:add_creature_at_position({}, 1, 1)
    local c2 = g:add_creature_at_position({}, 1, 10)

    g:creature_attack(c2, c1.safe)
    assert_true(g:is_alive(c1))
end

function test_creature_can_eat_dead_creatures_to_restore_energy()
    local g = Game:new()
    local dead = g:add_creature({brain=function() end})
    dead.alive = false

    local c = g:add_creature({brain=function()
        return Decision.Eat(dead.safe)
    end})

    local e1 = c.energy
    g:turn()
    assert_true(c.energy > e1)
end

function test_creature_cannot_eat_living_creatures()
    local g = Game:new()
    local alive = g:add_creature({})

    local c = g:add_creature({brain=function()
        return Decision.Eat(alive)
    end})

    local e1 = c.energy
    g:turn()
    assert_true(c.energy < e1)
end

function test_creature_can_breed_spawning_new_creatures()
    local g = Game:new()
    local c = g:add_creature({name="cat",
                              brain=function() return Decision.Breed(1) end})

    assert_equal(1, g:count_living_creatures_of_species("cat"))
    g:turn()
    assert_equal(2, g:count_living_creatures_of_species("cat"))
end

function test_creature_cannot_breed_with_negative_energy()
    local g = Game:new()
    local c = g:add_creature({name="cat",
                              brain=function() return Decision.Breed(-10) end})

    assert_equal(1, g:count_living_creatures_of_species("cat"))
    g:turn()
    assert_equal(0, g:count_living_creatures_of_species("cat"))
end

function test_creature_can_use_photosynthesis_to_restore_energy()
    local g = Game:new()
    local c = g:add_creature({plant=true,
        brain=function() return Decision.Photosynthesis() end})

    local e1 = c.energy
    g:turn()
    assert_true(c.energy > e1)
end

function test_photosynthesis_takes_a_lot_of_game_turns()
    local g = Game:new()

    g.action_turn_cost["photosynthesis"] = 3
    g.action_turn_cost["move"] = 1

    local plant_called = 0
    local animal_called = 0
    local plant = g:add_creature({
        plant=true,
        brain=function()
            plant_called = plant_called + 1
            return Decision.Photosynthesis()
        end})
    local animal = g:add_creature({
        name="animal",
        brain=function()
            animal_called = animal_called + 1
            return Decision.Move(Decision.Direction.NORTH)
        end})
    g:turn() -- calls both
    g:turn() -- just animal
    g:turn() -- just animal
    g:turn() -- calls both

    assert_equal(4, animal_called)
    assert_equal(2, plant_called)
end
