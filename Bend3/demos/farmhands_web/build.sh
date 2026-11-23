#!/bin/sh
# Checks the pure rules (12 laws) and the server, runs the rule audit, and
# builds the native server into Bend3/demos/farmhands_web/build/ (gitignored).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

mkdir -p Bend3/demos/farmhands_web/build
bend Bend3/demos/farmhands_web/farmhands_logic.bend --check-only
audit=$(bend Bend3/demos/farmhands_web/farmhands_logic.bend)
[ "$audit" = "12" ] || { echo "rule audit failed: $audit" >&2; exit 1; }
bend Bend3/demos/farmhands_web/web_farmhands.bend --check-only
bend Bend3/demos/farmhands_web/web_farmhands.bend -o Bend3/demos/farmhands_web/build/web_farmhands
printf '%s\n' 'Farmhands built; all pure rule proofs checked.'
