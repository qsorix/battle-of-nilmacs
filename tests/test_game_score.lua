require "lunit"
require "game"
require "decision"
module("test_game_score", lunit.testcase, package.seeall)

function test_score_is_kept_per_species()
    local g = Game:new()
    g:add_species({brain=function() end, name="cats"})
    g:add_species({brain=function() end, name="dogs"})

    g:species_add_points("cats", 10)

    assert_equal(10, g:species_score("cats"))
    assert_equal(0,  g:species_score("dogs"))
end

function test_score_increases_for_gained_energy()
    local g = Game:new()
    g:set_size(2,2)
    local f = g:add_creature({brain=function() end, name="food"})
    local e = g:add_creature({brain=function() end, name="eater"})
    g:creature_attack(e, f.safe)
    g:creature_eat(e, f.safe)

    assert_equal(0, g:species_score("food"))
    assert_true(g:species_score("eater") > 0)
end

function test_no_score_is_awarded_for_eating_the_same_species()
    local g = Game:new()
    g:set_size(2,2)
    local species = {brain=function() end, name="species"}
    local f = g:add_creature(species)
    local e = g:add_creature(species)
    g:creature_attack(e, f.safe)
    g:creature_eat(e, f.safe)

    assert_equal(0, g:species_score("species"))
end
