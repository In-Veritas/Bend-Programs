#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

node bend-ts/src/main.ts gabriel_demos/bendjogos_web/web_bendjogos.bend --no-halt -o gabriel_demos/bendjogos_web/web_bendjogos

printf '%s\n' 'BendJogos services built.'
