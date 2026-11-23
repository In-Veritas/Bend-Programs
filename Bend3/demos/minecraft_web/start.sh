#!/bin/sh
# Starts Block World from the repository root (its page path is root-relative).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

if [ ! -x Bend3/demos/minecraft_web/build/web_minecraft ]; then
  ./Bend3/demos/minecraft_web/build.sh
fi

exec ./Bend3/demos/minecraft_web/build/web_minecraft
