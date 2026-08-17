#!/usr/bin/env bash
# check.sh -- run every Bend program in a folder and diagnose what happened.
#
# For each .bend file it walks four stages and reports where it got to:
#
#   CHECK    parse + typecheck + interpret     (bend f.bend)
#   COMPILE  emit the standalone C file        (bend f.bend --compile)
#   BUILD    clang the C file                  (native binary)
#   RUN      execute the native binary
#
# A stage only runs if the previous one passed; anything not reached is "-".
# The DIAGNOSIS column is the interpreted result on success, or the reason it
# stopped (parse error / type error / linearity / halt / crash / timeout ...).
#
# Usage:
#   ./check.sh [dir]              # default: this script's own directory
#   ./check.sh -v [dir]           # -v: print full error text for failures
#   ./check.sh --no-native [dir]  # skip the COMPILE/BUILD/RUN stages
#
# The checker is found at $BEND_REPO/bend-ts/src/bend.ts, where BEND_REPO
# defaults to this repo. To test against a different checkout (e.g. a worktree
# of origin/main before you pull):
#   BEND_REPO=/path/to/other/bend3 ./check.sh
#
# Per-file pragmas, read from comment lines anywhere in the file:
#   # no-halt              pass --no-halt (non-structural or mutual recursion)
#   # run-args: a.txt b    argv for the native run
#   # stdin: file.txt      feed this file to the native run's stdin
#   # skip-native          check only; don't try to compile/build/run
#
# NB: written for bash 3.2 -- the version macOS ships. No mapfile, no assoc
# arrays, and no `set -u` (bash 3.2 treats an empty array as unbound under it).
set -o pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEND_REPO="${BEND_REPO:-$(cd "$SELF_DIR/.." && pwd)}"
BEND="$BEND_REPO/bend-ts/src/bend.ts"

VERBOSE=0
NATIVE=1
DIR=""
for a in "$@"; do
  case "$a" in
    -v|--verbose)   VERBOSE=1 ;;
    --no-native)    NATIVE=0 ;;
    -h|--help)      sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)              DIR="$a" ;;
  esac
done
DIR="${DIR:-$SELF_DIR}"
DIR="$(cd "$DIR" && pwd)"

CHECK_TIMEOUT=60
RUN_TIMEOUT=30
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Current Bend3 resolves every import relative to the importing file and has
# no package search path. Stage the selected folder beside the current
# checkout's bend-base; the source folder itself remains the source of truth.
ln -s "$BEND_REPO/bend-base" "$WORK/bend-base"
ln -s "$DIR" "$WORK/programas_gabriel"

if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; D=$'\e[2m'; Z=$'\e[0m'
else
  R=""; G=""; Y=""; B=""; D=""; Z=""
fi

if [ ! -f "$BEND" ]; then
  echo "${R}no checker at $BEND${Z}" >&2
  echo "set BEND_REPO to a bend3 checkout, e.g. BEND_REPO=/path/to/bend3 $0" >&2
  exit 1
fi

# `timeout` is not in macOS's base install; fall back to running bare.
if command -v timeout >/dev/null 2>&1;   then TO="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout"
else TO=""; fi
run_to () { local s="$1"; shift; if [ -n "$TO" ]; then "$TO" "$s" "$@"; else "$@"; fi; }

HAVE_CLANG=1
command -v clang >/dev/null 2>&1 || HAVE_CLANG=0

# Vintage probe. Current programs use function-form main and the current CLI.
PROBE="$WORK/probe.bend"
printf 'def f(x: U32) -> U32:\n  x + 1\n\ndef main() -> U32:\n  f(1)\n' >"$PROBE"
if ! run_to 30 bun "$BEND" "$PROBE" >/dev/null 2>&1; then
  echo "${R}${B}this checker predates the new syntax${Z}" >&2
  echo "  $BEND" >&2
  echo "  rejects a minimal current-syntax program, so it cannot parse this folder." >&2
  echo >&2
  echo "  fix: ${B}git pull${Z} in $BEND_REPO   (see MIGRATION.md §0)" >&2
  echo "  or:  point BEND_REPO at a checkout that has it:" >&2
  echo "       ${D}BEND_REPO=/path/to/new/bend3 $0${Z}" >&2
  exit 2
fi

# classify <exit> <output> -- turn a bend failure into a short diagnosis
classify () {
  local code="$1" out="$2"
  if [ "$code" -eq 124 ]; then echo "timeout (>${CHECK_TIMEOUT}s)"; return; fi
  local first
  first="$(printf '%s' "$out" | grep -v '^$' | head -1)"
  case "$out" in
    *"Location:"*|*"expected "*)
      case "$first" in
        expected*)                     echo "parse error: $first"; return ;;
      esac ;;
  esac
  case "$first" in
    Mismatch*)                         echo "type error (Mismatch)" ;;
    Usage*)                            echo "linearity error (Usage)" ;;
    NotBound*)                         echo "unbound name" ;;
    NonInfer*)                         echo "not inferable (NonInfer)" ;;
    "not Data"*)                       echo "sort error: $first" ;;
    "non-terminating recursion"*)      echo "halt: $first" ;;
    "duplicate buffer key"*)           echo "array literal: $first" ;;
    flatten*)                          echo "match error: $first" ;;
    *"stack overflow"*)                echo "stack overflow" ;;
    "")                                echo "failed (no output, exit $code)" ;;
    *)                                 echo "$first" ;;
  esac
}

pragma () { grep -m1 -oE "^#[[:space:]]*$1:[[:space:]]*.*" "$2" 2>/dev/null | sed -E "s/^#[[:space:]]*$1:[[:space:]]*//"; }
has_pragma () { grep -qE "^#[[:space:]]*$1[[:space:]]*$" "$2" 2>/dev/null; }

# Colour has to be applied *around* padding, never inside a printf width --
# escape bytes count toward %-Ns and wreck the columns.
colour_of () {
  case "$1" in
    ok)               printf '%s' "$G" ;;
    fail|crash|hang)  printf '%s' "$R" ;;
    n/a)              printf '%s' "$Y" ;;
    *)                printf '%s' "$D" ;;
  esac
}
cell () { # <text> <width> [colour]
  local txt="$1" w="$2" col="${3-}" pad
  pad=$(( w - ${#txt} )); [ "$pad" -lt 0 ] && pad=0
  printf '%s%s%s%*s' "$col" "$txt" "$Z" "$pad" ""
}
row () { # <name> <check> <compile> <build> <run> <diagnosis>
  cell "$1" 19
  cell "$2" 8  "$(colour_of "$2")"
  cell "$3" 9  "$(colour_of "$3")"
  cell "$4" 7  "$(colour_of "$4")"
  cell "$5" 6  "$(colour_of "$5")"
  printf '%s\n' "$6"
}

FILES=()
while IFS= read -r line; do FILES+=("$line"); done < <(find "$DIR" -maxdepth 1 -name '*.bend' | sort)
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "no .bend files in $DIR"; exit 0
fi

REV="$(git -C "$BEND_REPO" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "${B}bend${Z}  $BEND ${D}($REV)${Z}"
echo "${B}dir${Z}   $DIR"
[ "$HAVE_CLANG" -eq 0 ] && echo "${Y}note${Z}  clang not found -- BUILD/RUN skipped"
echo

printf '%s' "$B"; row PROGRAM CHECK COMPILE BUILD RUN DIAGNOSIS; printf '%s' "$Z"
printf '%s\n' "$(printf '%.0s-' {1..96})"

FAILED=(); DETAIL=()
n_ok=0; n_bad=0
c_comp=0; c_build=0; c_run=0; c_na=0; c_runbad=0

for f in "${FILES[@]}"; do
  name="$(basename "$f" .bend)"
  s_check="-"; s_comp="-"; s_build="-"; s_run="-"; diag=""

  flags=()
  has_pragma "no-halt" "$f" && flags+=(--no-halt)
  staged="$WORK/programas_gabriel/$(basename "$f")"

  # --- CHECK -------------------------------------------------------------
  out="$(run_to "$CHECK_TIMEOUT" bun "$BEND" "$staged" "${flags[@]}" --eval 2>&1)"; code=$?
  if [ $code -ne 0 ]; then
    s_check="fail"
    diag="$(classify $code "$out")"
    FAILED+=("$name"); DETAIL+=("$out"); n_bad=$((n_bad+1))
    row "$name" "$s_check" "$s_comp" "$s_build" "$s_run" "$diag"
    continue
  fi
  s_check="ok"
  result="$(printf '%s' "$out" | head -1)"
  diag="$result"
  n_ok=$((n_ok+1))

  if [ "$NATIVE" -eq 0 ] || has_pragma "skip-native" "$f"; then
    row "$name" "$s_check" "-" "-" "-" "${diag:0:52}"
    continue
  fi

  # --- COMPILE -----------------------------------------------------------
  cfile="$WORK/$name.c"
  cout="$(run_to "$CHECK_TIMEOUT" bun "$BEND" "$staged" "${flags[@]}" --compile 2>&1 >"$cfile")"; code=$?
  if [ $code -ne 0 ] || [ ! -s "$cfile" ]; then
    s_comp="fail"
    diag="$result ${D}| compile: $(classify $code "$cout")${Z}"
    row "$name" "$s_check" "$s_comp" "-" "-" "$diag"
    continue
  fi
  s_comp="ok"; c_comp=$((c_comp+1))

  if [ "$HAVE_CLANG" -eq 0 ]; then
    row "$name" "$s_check" "$s_comp" "-" "-" "${diag:0:52}"
    continue
  fi

  # --- BUILD -------------------------------------------------------------
  bin="$WORK/$name.bin"
  berr="$(run_to "$CHECK_TIMEOUT" bun "$BEND" "$staged" "${flags[@]}" -o "$bin" 2>&1)"; code=$?
  if [ $code -ne 0 ]; then
    s_build="fail"
    diag="$result ${D}| clang: $(printf '%s' "$berr" | grep -m1 error: | head -1)${Z}"
    FAILED+=("$name (clang)"); DETAIL+=("$berr")
    row "$name" "$s_check" "$s_comp" "$s_build" "-" "$diag"
    continue
  fi
  s_build="ok"; c_build=$((c_build+1))

  # --- RUN ---------------------------------------------------------------
  args_line="$(pragma "run-args" "$f")"
  stdin_file="$(pragma "stdin" "$f")"
  rargs=()
  if [ -n "$args_line" ]; then
    # pragma paths are relative to the .bend file
    for w in $args_line; do
      case "$w" in /*) rargs+=("$w") ;; *) rargs+=("$(dirname "$f")/$w") ;; esac
    done
  fi
  if [ -n "$stdin_file" ]; then
    case "$stdin_file" in /*) sf="$stdin_file" ;; *) sf="$(dirname "$f")/$stdin_file" ;; esac
    rout="$(run_to "$RUN_TIMEOUT" "$bin" "${rargs[@]}" <"$sf" 2>&1)"; code=$?
  else
    rout="$(run_to "$RUN_TIMEOUT" "$bin" "${rargs[@]}" </dev/null 2>&1)"; code=$?
  fi

  native="$(printf '%s' "$rout" | grep -v '^note: no usable GPU' | head -1)"
  if [ $code -eq 124 ]; then
    s_run="hang"; c_runbad=$((c_runbad+1)); diag="$result ${D}| native: timeout${Z}"
  elif [ $code -ge 128 ]; then
    s_run="crash"; c_runbad=$((c_runbad+1)); diag="$result ${D}| native: signal $((code-128))${Z}"
    FAILED+=("$name (native)"); DETAIL+=("$rout")
  elif [ "$code" -ne 0 ]; then
    s_run="fail"; c_runbad=$((c_runbad+1)); diag="$result ${D}| native: exit $code${Z}"
    FAILED+=("$name (native)"); DETAIL+=("$rout")
  else
    s_run="ok"; c_run=$((c_run+1))
    if [ -n "$native" ]; then diag="$result ${D}| native: ${native:0:34}${Z}"; fi
  fi
  row "$name" "$s_check" "$s_comp" "$s_build" "$s_run" "$diag"
done

echo
n_tot=$((n_ok+n_bad))
echo "${B}$n_tot programs${Z}  check ${G}$n_ok ok${Z}$([ $n_bad -gt 0 ] && printf ", %s%s failed%s" "$R" "$n_bad" "$Z")"
if [ "$NATIVE" -eq 1 ]; then
  echo "${D}             compile $c_comp ok  |  build $c_build ok  |  run $c_run ok, $c_na n/a$([ $c_runbad -gt 0 ] && printf ", %s failed" "$c_runbad")${Z}"
fi

if [ "$VERBOSE" -eq 1 ] && [ "${#FAILED[@]}" -gt 0 ]; then
  for i in "${!FAILED[@]}"; do
    echo
    echo "${B}--- ${FAILED[$i]} ---${Z}"
    printf '%s\n' "${DETAIL[$i]}"
  done
elif [ "${#FAILED[@]}" -gt 0 ]; then
  echo "${D}re-run with -v for full error text${Z}"
fi

[ "$n_bad" -eq 0 ]
