#!/bin/sh
# Builds the native belote server into Bend3/demos/belote_web/build/ (gitignored).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

mkdir -p Bend3/demos/belote_web/build
bend Bend3/demos/belote_web/web_belote.bend --check-only
bend Bend3/demos/belote_web/web_belote.bend -o Bend3/demos/belote_web/build/web_belote
printf '%s\n' 'Built Bend3/demos/belote_web/build/web_belote.'
