#!/bin/sh
# Build the standalone Duck Hunt server with Bend 2.0.40 into build/ (gitignored).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

bend Bend3/demos/duck_hunt_web/web_duck_hunt.bend -o Bend3/demos/duck_hunt_web/build/web_duck_hunt
printf '%s\n' 'Duck Hunt built: Bend3/demos/duck_hunt_web/build/web_duck_hunt'
