#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

bun gabriel_demos/bendjogos_web/generate_modules.mjs
bun gabriel_demos/bendjogos_web/sync_core.mjs
if [ -f bend-ts/src/main.ts ]; then
  compiler=bend-ts/src/main.ts
else
  compiler=bend-ts/src/bend.ts
fi
bun "$compiler" gabriel_demos/bendjogos_web/web_bendjogos.bend --no-halt -o gabriel_demos/bendjogos_web/web_bendjogos

printf '%s\n' 'BendJogos services built.'
