#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

bun bend-ts/src/bend.ts gabriel_demos/poker_web/web_poker.bend --no-halt -o gabriel_demos/poker_web/web_poker
printf '%s\n' 'Bend3 Poker built.'
