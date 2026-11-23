#!/bin/sh
# Serves on 0.0.0.0:8088 from the repository root (index.html is read
# from Bend3/demos/bend_obfuscator_web/ at request time).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

exec ./Bend3/demos/bend_obfuscator_web/build/web_obfuscator
