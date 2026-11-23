#!/bin/sh
# Start Duck Hunt on port 8089 from the repository root (its page path is
# repository-root relative), building it first if needed.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

if [ ! -x Bend3/demos/duck_hunt_web/build/web_duck_hunt ]; then
  ./Bend3/demos/duck_hunt_web/build.sh
fi

exec ./Bend3/demos/duck_hunt_web/build/web_duck_hunt
