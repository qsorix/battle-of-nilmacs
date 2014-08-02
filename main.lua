#!/usr/bin/env lua

require "luarocks.loader"
require "game"

local function load_species(game, path)
    -- File with species definition should end with a return statement that
    -- gives back a table defining the species.
    -- Load the file in a sand box environment, and add species to the game.

    local species_code, err = loadfile(path)
    if not species_code then
        error(err)
    end

    setfenv(species_code, game:create_sandbox())

    local success, result = pcall(species_code)
    if not success then
        error(result)
    end

    if not result.name then
        error("Species do not define name " .. path)
    end

    game:add_species(result)

    return result.name
end

local function parse_arguments()
    local argparse = require "argparse"
    local parser = argparse()

    parser:option "--randomseed"
        :args "1"
        :convert(tonumber)
        :description "seed for random numbers"
    parser:option "--size"
        :args "2"
        :argname {"<x>", "<y>"}
        :convert(tonumber)
        :description "size of the game world"
    parser:flag "--dont-draw"
        :target "dont_draw"
    parser:flag "--debug"
    parser:option "--initial-energy"
         :args "1"
         :target "initial_energy"
         :convert(tonumber)

    local q = parser:command "qualification"
    q:option "--turns"
        :convert(tonumber)
        :default "10000"
        :description "how many turns to run"
    q:option "--ecosystem"
        :args "+"
        :description "files with ecosystem species"
    q:option "--player"
        :args "1"
        :convert(function(a) return {a} end)
        :description "file with species to be qualified for the tournament"

    local t = parser:command "tournament"
    t:option "--turns"
        :convert(tonumber)
        :default "100000"
        :description "how many turns to run"
    t:option "--ecosystem"
        :args "+"
        :description "files with ecosystem species"
    t:option "--player"
        :args "+"
        :description "files with species to take part in tournament"

q:description
[[Qualification is a special mode of the simulation where only one player's
species is introduced. The species need to survive for a given number of turns.
This mode is supposed to pre-test player's submission. Number of turns should be
picked to force species to eat.  Qualification can run with an ecosystem, so
there is something to eat.

Game will use non-zero exit code if the challange failed.]]

t:description
[[Tournament is a simulation of all players' species living in the same
environment. Tournament runs until just one player's species survives. If this
does not happen before turns limit is reached, score is used to select the
winner.]]

    local args = parser:parse()

    if args.qualification and not args.player then
        parser:error("qualification initiated without a player")
    end
    if args.tournament and not args.player then
        parser:error("tournament initiated without players. you suck at options")
    end

    return args
end

local function create_game(args)
    local g = Game:new()

    if args.debug then
        g.print_errors = true
        g.panic_on_errors = true
        g.sandbox_includes_global_scope = true
    end
    g:set_initial_energy(args.initial_energy or 3000)

    if args.size then
        g:set_size(args.size[1], args.size[2])
    else
        g:set_size(80, 35)
    end

    if args.randomseed then
        math.randomseed(args.randomseed)
    else
        math.randomseed(os.time())
    end

    return g
end

local function main()
    local args = parse_arguments()
    local g = create_game(args)

    for _, path in ipairs(args.ecosystem) do
        load_species(g, path)
    end

    if args.qualification then
        local player_name = load_species(g, args.player[1])

        local turns_limit_reached = false

        while not g:finished() do
            g:turn()
            if not args.dont_draw then
                g:draw()
            end
            if g.turn_number >= args.turns then
                turns_limit_reached = true
                break
            end
        end

        if turns_limit_reached and
           g:count_living_creatures_of_species(player_name) > 0 then
            print(player_name .. " passed qualifications")
            os.exit(0)
        else
            print(player_name .. " failed qualifications")
            os.exit(1)
        end

    elseif args.tournament then
        local player_names = {}

        for _, path in ipairs(args.player) do
            table.insert(player_names, load_species(g, path))
        end

        while not g:finished() and g.turn_number < args.turns do
            g:turn()
            if not args.dont_draw then
                g:draw()
            end
        end

        -- TODO(qsorix): what when no player survived?

        local best_score = nil
        local best_player = nil
        for _, name in ipairs(player_names) do
            if g:count_living_creatures_of_species(name) > 0 then
                if (g.species_scores[name] or 0) > (best_score or 0) then
                    best_score = g.species_scores[name]
                    best_player = name
                end
            end
        end

        print(best_player .. " has won")
        os.exit(0)
    end
end

main()
