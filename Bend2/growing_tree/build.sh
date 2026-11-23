#!/bin/sh
# Check, test, build the native app and the single-file web page.
#   sh build.sh            (needs `bend` on PATH; `bun` for the web inliner)
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${TMPDIR:-/tmp}/growing_tree_build"
mkdir -p "$OUT"
cd "$DIR"
bend main.bend --check-only
bend test.bend -o "$OUT/test" && "$OUT/test"
bend main.bend -o "$OUT/growing_tree"
echo "native: $OUT/growing_tree"
rm -rf "$OUT/web"
bend web/index.html -o "$OUT/web"
bun web/inline.mjs "$OUT/web" growing_tree.html
