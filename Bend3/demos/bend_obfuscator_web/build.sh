#!/bin/sh
# Builds the obfuscator server into build/ (run from anywhere).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

if command -v node >/dev/null 2>&1; then js=node; else js=bun; fi
"$js" Bend3/demos/bend_obfuscator_web/test_obfuscator.mjs
mkdir -p Bend3/demos/bend_obfuscator_web/build
bend Bend3/demos/bend_obfuscator_web/web_obfuscator.bend -o Bend3/demos/bend_obfuscator_web/build/web_obfuscator
printf '%s\n' 'Bend Source Obfuscator built.'
