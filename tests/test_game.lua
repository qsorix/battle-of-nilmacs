require "lunit"
require "game"
require "decision"
module("test_game", lunit.testcase, package.seeall)

function test_on_each_turn_game_invokes_creatures()
    local g = Game:new()
    local invoked1 = false
    local invoked2 = false
    g:add_creature({brain=function() invoked1 = true end})
    g:add_creature({brain=function() invoked2 = true end})

    g:turn()
    assert_true(invoked1)
    assert_true(invoked2)
end

function test_on_each_turn_only_living_creatures_are_invoked()
    local g = Game:new()
    local invoked = false
    c = g:add_creature({brain=function() invoked = true end})
    c.alive = false

    g:turn()

    assert_false(invoked)
end

function test_creatures_are_activated_in_order_of_their_random_identity()
    -- to make replays possible, I need some deterministic approach to
    -- activation of creatures. And a fair one. So I random their priority upon
    -- creation, and then creatures active during a given turn are sorted by
    -- this number
    local g = Game:new()
    local invoked_first = ""
    c1 = g:add_creature({brain=function()
        if invoked_first=="" then invoked_first = "c1" end end})
    c2 = g:add_creature({brain=function()
        if invoked_first=="" then invoked_first = "c2" end end})

    assert_number(c1.priority)
    assert_number(c2.priority)
    assert_true(c1.priority ~= c2.priority)

    g:turn()

    if (c1.priority < c2.priority) then
        assert_equal("c1", invoked_first)
    else
        assert_equal("c2", invoked_first)
    end
end

function test_creatures_are_placed_on_a_grid()
    local g = Game:new()
    local c = g:add_creature({})

    assert_number(c.x)
    assert_number(c.y)
end


function test_initially_creatures_are_alive()
    local g = Game:new()
    local c = g:add_creature({})

    assert_true(g:is_alive(c))
end

function test_creature_dies_when_it_has_no_energy()
    local g = Game:new()
    local c = g:add_creature({})

    c.energy = 0
    g:turn()

    assert_false(g:is_alive(c))
end

function test_creatures_lose_energy_on_each_turn()
    local g = Game:new()
    g:set_initial_energy(100)
    local c = g:add_creature({})

    g:turn()
    assert_true(c.energy < 100)
end

function test_game_is_finished_when_there_are_no_creatures()
    local g = Game:new()
    assert_true(g:finished())
end

function test_game_ends_when_all_living_creatures_are_of_the_same_species()
    local g = Game:new()
    local species={name="cat"}
    g:add_creature(species)
    g:add_creature(species)
    assert_true(g:finished())
end

function test_game_is_active_while_there_are_at_least_two_living_species()
    local g = Game:new()
    g:add_creature({name="cat"})
    g:add_creature({name="dog"})

    assert_false(g:finished())
end

function test_game_ends_when_last_creature_of_another_species_dies()
    local g = Game:new()
    g:set_size(2,2)
    local c1 = g:add_creature({name="cat"})
    local c2 = g:add_creature({name="dog"})

    g:creature_attack(c2, c1.safe)

    assert_false(g:is_alive(c1))
    assert_true(g:finished())
end

function test_eaten_creatures_are_removed_from_the_game()
    local g = Game:new()
    local c1 = g:add_creature({})
    local c2 = g:add_creature({})
    c2.alive = false

    assert_true(g.creatures[c2] ~= nil)
    g:creature_eat(c1, c2.safe)
    assert_nil(g.creatures[c2])
end

function test_eating_restores_energy_based_on_amount_of_flesh_of_the_prey()
    local g = Game:new()
    local c1 = g:add_creature({})
    local c2 = g:add_creature({})
    c2.alive = false

    c2.flesh = 8
    local c1_energy_before = c1.energy
    g:creature_eat(c1, c2.safe)

    assert_equal(c1.energy, c1_energy_before + 8)
end

function test_when_adding_species_initial_creatures_are_added()
    local g = Game:new()
    g:add_species({name="cat"})
    assert_true(g:count_creatures_of_species("cat") > 1)
end

function test_number_of_initial_creatures_depends_on_species_starting_energy()
    local g = Game:new()
    g:add_species({name="cat", initial_energy=5})
    g:add_species({name="dog", initial_energy=10})
    local cats = g:count_creatures_of_species("cat")
    local dogs = g:count_creatures_of_species("dog")
    assert_true(cats > 1)
    assert_true(dogs > 1)
    assert_true(cats > dogs)
end

function test_breeding_adds_a_creature_of_the_same_species_and_brain()
    local g = Game:new()

    local run_counter = 0
    local c1 = g:add_creature({name="breeder", brain=function() run_counter = run_counter + 1 end})
    local c2 = g:creature_breed(c1, 1)

    g:turn()
    assert_equal("breeder", c2.species)
    assert_equal(2, run_counter)
end

function test_breeding_uses_energy_and_passes_some_offspring()
    local g = Game:new()
    g.energy_cost_breeding = 10

    local c = g:add_creature({})

    local e_before = c.energy
    local c_new = g:creature_breed(c, 5)
    local e_after = c.energy

    assert_equal(e_before - g.energy_cost_breeding - 5, e_after)
    assert_equal(c_new.energy, 5)
end

function test_bred_creature_has_amount_of_flesh_based_on_its_initial_energy()
    local g = Game:new()
    local c = g:add_creature({})
    local offspring = g:creature_breed(c, 5)
    assert_equal(offspring.energy, 5)
    assert_equal(offspring.flesh,  5)
end


function test_breeding_is_not_possible_with_too_little_energy()
    local g = Game:new()
    g.energy_cost_breeding = 10

    local c = g:add_creature({})
    c.energy = 19
    assert_nil(g:creature_breed(c, 10))
end

function test_bred_creatures_are_placed_near_parents()
    local g = Game:new()
    g.breed_distance = 2
    local parent = g:add_creature({})
    local offspring = g:creature_breed(parent, 5)

    assert_true(math.abs(parent.x - offspring.x) <= 2)
    assert_true(math.abs(parent.y - offspring.y) <= 2)
    assert_true(parent.x ~= offspring.x  or parent.y ~= offspring.y)
end

function test_creatures_have_memory()
    local g = Game:new()
    local c = g:add_creature({brain=function() Self.memory['foo']='bar' end})
    g:turn()
    assert_true(c.memory['foo'] == 'bar')
end

function test_creatures_memory_is_not_shared_by_offsprings()
    local g = Game:new()
    local parent = g:add_creature({brain=function() Self.memory['x']=1 end})
    g:turn()
    assert_true(parent.memory['x'] == 1)
    local offspring = g:creature_breed(parent, 5)
    assert_nil(offspring.memory['x'])
end

function test_creatures_can_check_game_world_size()
    local g = Game:new()
    g:set_size(13, 18)
    local x, y
    local parent = g:add_creature({brain=function()
        x = World.X
        y = World.Y
    end})
    g:turn()
    assert_equal(13, x)
    assert_equal(18, y)
end

function test_creatures_can_check_if_game_runs_in_sanbox()
    function test(value)
        local g = Game:new()
        g.sandbox_includes_global_scope = value

        local disabled
        local c = g:add_creature({brain=function()
            disabled = World.SandboxDisabled
        end})
        g:turn()

        assert_equal(disabled, value)
    end

    test(true)
    test(false)
end

function test_creatures_run_in_a_sandbox_and_die_if_they_break_it()
    local g = Game:new()

    local c = g:add_creature({brain=function() loadstring("return nil") end})
    g:turn()

    assert_false(g:is_alive(c))
end

function test_creatures_cannot_break_sandbox_environment_of_others()
    local g = Game:new()

    local evil = g:add_creature({brain=function() math.abs = 1 end})
    g:turn()

    local good = g:add_creature({brain=function() math.abs(-2) end})
    g:turn()

    assert_true(g:is_alive(good))
end

function test_creatures_cannot_set_their_energy()
    local g = Game:new()
    g:set_initial_energy(10)
    local c = g:add_creature({brain=function() Self.energy = 1000 end})
    local e = c.energy
    g:turn()
    -- killed by doing illegal operation
    assert_false(g:is_alive(c))
end

function test_creatures_cannot_set_energy_of_creatures_they_see()
    local g = Game:new()
    g:set_size(2, 2)
    g:set_initial_energy(10)
    local _ = g:add_creature({})
    local c = g:add_creature({brain=function()
        local s = Action.Look(2)
        s[1].energy = 1000
    end})
    g:turn()
    -- killed by doing illegal operation
    assert_false(g:is_alive(c))
end

function test_dead_creatures_decompose()
    local g = Game:new()
    g.turn_decompose_speed = -2
    local c = g:add_creature({})
    c.alive = false
    c.flesh = 10
    g:turn()
    assert_equal(10-2, c.flesh)
end

function test_dead_creatures_are_removed_after_they_decompose()
    local g = Game:new()
    g.turn_decompose_speed = -2
    local c = g:add_creature({})
    c.alive = false
    c.flesh = 1
    g:turn()
    assert_nil(g.creatures[c])
end

function test_photosynthesis_is_available_on_to_plants()
    local g = Game:new()
    local c = g:add_creature({plant=false, brain=function() return Decision.Photosynthesis() end})
    local p = g:add_creature({plant=true, brain=function() return Decision.Photosynthesis() end})
    g:turn()
    assert_false(g:is_alive(c))
    assert_true(g:is_alive(p))
end

function test_plants_cannot_move()
    local g = Game:new()
    local p = g:add_creature({plant=true, brain=function() return Decision.Move({dx=1, dy=0}) end})
    g:turn()
    assert_false(g:is_alive(p))
end

function test_photosynthesis_gives_less_energy_when_many_plants_are_nearby()
    local species = {
        plant=true,
        brain=function()
            return Decision.Photosynthesis()
        end
    }

    local g = Game:new()
    g:set_size(1,1)
    local p1 = g:add_creature(species)
    local e1 = p1.energy
    g:turn()
    local e2 = p1.energy

    local energy_gain_with_one_creature = e2-e1

    local g = Game:new()
    g:set_size(1,1)
    local p1 = g:add_creature(species)
    local p2 = g:add_creature(species)
    local e1 = p1.energy
    g:turn()
    local e2 = p1.energy
    local energy_gain_with_two_creatures = e2-e1

    assert_true(energy_gain_with_two_creatures < energy_gain_with_one_creature)
end
