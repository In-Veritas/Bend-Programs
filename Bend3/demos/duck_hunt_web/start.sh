#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

if [ ! -x gabriel_demos/duck_hunt_web/web_duck_hunt ]; then
  ./gabriel_demos/duck_hunt_web/build.sh
fi

exec ./gabriel_demos/duck_hunt_web/web_duck_hunt
