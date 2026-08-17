#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

bun bend-ts/src/bend.ts gabriel_demos/belote_web/web_belote.bend --no-halt -o gabriel_demos/belote_web/web_belote
printf '%s\n' 'Belote built.'
