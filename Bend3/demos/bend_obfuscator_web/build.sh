#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

node gabriel_demos/bend_obfuscator_web/test_obfuscator.mjs
bun bend-ts/src/bend.ts gabriel_demos/bend_obfuscator_web/web_obfuscator.bend --no-halt -o gabriel_demos/bend_obfuscator_web/web_obfuscator
printf '%s\n' 'Bend3 Source Obfuscator built.'
