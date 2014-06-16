# battle-of-nilmacs

Battle of Nilmacs is a simulation game. Nilmacs are creatures inhabiting the
game's world. They compete for food, aiming for a complete domination!

In order to play, you must write an AI algorithm for one species. See a simple
(and rather stupid!) example at [players directory](players/sample.lua).

To do that, you'll have to clone this repository, learn some Lua and test your
creation!

## Installation

Running the game is part of the challenge, so I'm providing only brief
instructions. Read manuals and follow them and you'll be fine.

Clone this repository and run

```bash
$ ./go.sh
```

You will get some errors if you don't have Lua installed, if you don't have
[luarocks](http://luarocks.org/) installed, or if you don't have
[argparse](https://github.com/mpeterv/argparse). Resolve them.

## Creating Nilmacs

See the examples and add your own species in the players directory. Run the
game, see if your creation manages to survive. If it does, improve it more!

## Tournament

The game itself has no support for keeping track of the entries contestants
submit. Someone will need to organize the tournament for you. Or maybe you're
going to host a tournament for your friends? In either case, the entries (files
with species definition) will need to be gathered in the players directory, and
then the tournament.sh script should be run to select the winner.

Tournament consists of two stages. First qualifications round is held. Only
species that manage to survive without competition enter the next round. This
step will get rid of all weak organisms.

The second and last stage is the tournament itself. All players start at once,
in the same world. They need to destroy their opponents or find another way of
survival. The tournament ends when only one species is left or the turn limit is
reached. In the latter case, the species with highest score wins.

## FAQ

See project's wiki on github.
