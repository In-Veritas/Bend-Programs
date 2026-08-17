#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

bun bend-ts/src/bend.ts gabriel_demos/club_corvid_web/web_club_corvid.bend --no-halt -o gabriel_demos/club_corvid_web/web_club_corvid
printf '%s\n' 'Club Corvid built.'
