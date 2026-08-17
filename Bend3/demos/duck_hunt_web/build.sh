#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

bun bend-ts/src/bend.ts gabriel_demos/duck_hunt_web/web_duck_hunt.bend --no-halt -o gabriel_demos/duck_hunt_web/web_duck_hunt
printf '%s\n' 'Duck Hunt built.'
