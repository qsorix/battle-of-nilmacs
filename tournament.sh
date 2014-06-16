#!/bin/sh

SEED="1"
SIZE="80 35"
QUALIFICATION_TURNS=10000
TOURNAMENT_TURNS=50000

OPTS="--randomseed $SEED --size $SIZE --dont-draw"
QUALIFIED_DIR=qualified

function qualifies()
{
    ./main.lua $OPTS qualification \
        --turns $QUALIFICATION_TURNS \
        --ecosystem ecosystem/* \
        --player "$PLAYER"
}

function qualifications()
{
    rm -rf "$QUALIFIED_DIR/"
    mkdir -p "$QUALIFIED_DIR"

    for PLAYER in players/*.lua; do
        if qualifies "$PLAYER"; then
            cp "$PLAYER" "$QUALIFIED_DIR"
        fi
    done
}

function tournament()
{
    ./main.lua $OPTS tournament \
        --turns $TOURNAMENT_TURNS \
        --ecosystem ecosystem/* \
        --player "$QUALIFIED_DIR"/*
}

qualifications
tournament
