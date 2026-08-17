#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

bun bend-ts/src/bend.ts gabriel_demos/minecraft_web/web_minecraft.bend --no-halt -o gabriel_demos/minecraft_web/web_minecraft
printf '%s\n' 'Block World built.'
