#!/bin/sh
# Builds Block World with Bend 2.0.40 into minecraft_web/build/ (gitignored).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

mkdir -p Bend3/demos/minecraft_web/build
bend Bend3/demos/minecraft_web/web_minecraft.bend -o Bend3/demos/minecraft_web/build/web_minecraft
printf '%s\n' 'Block World built: Bend3/demos/minecraft_web/build/web_minecraft'
