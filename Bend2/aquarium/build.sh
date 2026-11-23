#!/bin/sh
# Check, test, build natively and rebuild the single-file web page.
#   sh build.sh            (needs `bend` 2.0.40 and `bun` on PATH)
set -e
cd "$(dirname "$0")"
OUT="${TMPDIR:-/tmp}"
bend main.bend --check-only
bend test.bend -o "$OUT/aquarium_test"
"$OUT/aquarium_test"
bend main.bend -o "$OUT/aquarium"
echo "native build: $OUT/aquarium (run it from a desktop session)"
rm -rf "$OUT/aquarium_web"
bend web/index.html -o "$OUT/aquarium_web"
bun web/inline.mjs "$OUT/aquarium_web" aquarium.html
