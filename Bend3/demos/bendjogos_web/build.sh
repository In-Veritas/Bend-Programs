#!/bin/sh
# Builds the unified BendJogos hub into Bend3/demos/bendjogos_web/build/
# (gitignored). The hub imports every standalone demo source directly, so
# there is no module generation step any more.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

# Refresh the Bend2 Core observer assets under core/ when bun is available;
# the checked-in copies are served otherwise.
if command -v bun >/dev/null 2>&1; then
  bun Bend3/demos/bendjogos_web/sync_core.mjs
else
  printf '%s\n' 'bun not found: serving the checked-in core/ assets.'
fi

mkdir -p Bend3/demos/bendjogos_web/build
bend Bend3/demos/bendjogos_web/web_bendjogos.bend --check-only
# A long build: about 1.5 min and up to ~16 GB of memory on the porting machine.
bend Bend3/demos/bendjogos_web/web_bendjogos.bend -o Bend3/demos/bendjogos_web/build/web_bendjogos
printf '%s\n' 'Built Bend3/demos/bendjogos_web/build/web_bendjogos.'
