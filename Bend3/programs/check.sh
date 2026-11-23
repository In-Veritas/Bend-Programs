#!/usr/bin/env bash
# check.sh -- run every Bend program in a folder through the installed `bend`
# CLI (Bend 2.0.40) and diagnose what happened.
#
# For each .bend file it walks five stages and reports where it got to:
#
#   CHECK   check proofs, types, termination   bend f.bend --check-only
#   RUN     run main                           bend f.bend [run-args]
#           (a value main is normalized and printed; an IO main is compiled
#           and run)
#   C       emit the standalone C file         bend f.bend -o f.c
#   BUILD   build a native binary              bend f.bend -o f
#   NATIVE  execute the native binary          ./f [run-args]
#
# A stage only runs if the previous one passed; anything not reached is "-".
# RUN and NATIVE are compared with the file's `# expect:` line, if any, and
# NATIVE is also compared with RUN. The DIAGNOSIS column shows the result on
# success, or the reason it stopped.
#
# Usage:
#   ./check.sh [dir]              # default: this script's own directory
#   ./check.sh -v [dir]           # -v: print full error text for failures
#   ./check.sh --no-native [dir]  # skip the C/BUILD/NATIVE stages
#
# `bend` is taken from $BEND if set, else from PATH.
#
# Per-file pragmas, read from comment lines anywhere in the file:
#   # run-args: a.txt b    argv for RUN and NATIVE (run from the file's dir)
#   # stdin: file.txt      feed this file to RUN's and NATIVE's stdin
#   # expect: text         the first line of output RUN and NATIVE must print
#   # skip-native          check and run only; don't emit C or build
#
# NB: written for bash 3.2 -- the version macOS ships. No mapfile, no assoc
# arrays, and no `set -u` (bash 3.2 treats an empty array as unbound under it).
set -o pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEND="${BEND:-$(command -v bend 2>/dev/null)}"

VERBOSE=0
NATIVE=1
DIR=""
for a in "$@"; do
  case "$a" in
    -v|--verbose)   VERBOSE=1 ;;
    --no-native)    NATIVE=0 ;;
    -h|--help)      sed -n '2,34p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)              DIR="$a" ;;
  esac
done
DIR="${DIR:-$SELF_DIR}"
DIR="$(cd "$DIR" && pwd)"

CHECK_TIMEOUT=120
RUN_TIMEOUT=60
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; D=$'\e[2m'; Z=$'\e[0m'
else
  R=""; G=""; Y=""; B=""; D=""; Z=""
fi

if [ -z "$BEND" ] || [ ! -x "$BEND" ]; then
  echo "${R}no bend found${Z} -- install it (curl -fsSL https://bend-lang.com/install.sh | sh)" >&2
  echo "or point BEND at the binary: BEND=/path/to/bend $0" >&2
  exit 1
fi

# `timeout` is not in macOS's base install; fall back to running bare.
if command -v timeout >/dev/null 2>&1;   then TO="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout"
else TO=""; fi
run_to () { local s="$1"; shift; if [ -n "$TO" ]; then "$TO" "$s" "$@"; else "$@"; fi; }

HAVE_CLANG=1
command -v clang >/dev/null 2>&1 || HAVE_CLANG=0

# classify <exit> <output> -- turn a bend failure into a short diagnosis
classify () {
  local code="$1" out="$2" first
  if [ "$code" -eq 124 ]; then echo "timeout"; return; fi
  if [ "$code" -ge 128 ]; then echo "signal $((code-128))"; return; fi
  first="$(printf '%s\n' "$out" | grep -v '^$' | grep -vE '^(SOME PROOFS FAIL|Error:)$' | head -1)"
  local loc
  loc="$(printf '%s\n' "$out" | grep -m1 '^Location:' | sed -E 's/^Location:[[:space:]]*//')"
  case "$out" in
    *"- expected :"*)
      local e
      e="$(printf '%s\n' "$out" | grep -m1 -- '- expected :' | sed 's/^- expected : //')"
      echo "${loc:+in $loc: }expected ${e:0:64}"; return ;;
    *"- message  :"*)
      echo "$(printf '%s\n' "$out" | grep -m1 -- '- message  :' | sed 's/^- message  : //')${loc:+ (in $loc)}"; return ;;
  esac
  case "$first" in
    "")  echo "failed (no output, exit $code)" ;;
    *)   echo "$first" ;;
  esac
}

pragma () { grep -m1 -oE "^#[[:space:]]*$1:[[:space:]]*.*" "$2" 2>/dev/null | sed -E "s/^#[[:space:]]*$1:[[:space:]]*//"; }
has_pragma () { grep -qE "^#[[:space:]]*$1[[:space:]]*$" "$2" 2>/dev/null; }

# Colour has to be applied *around* padding, never inside a printf width --
# escape bytes count toward %-Ns and wreck the columns.
colour_of () {
  case "$1" in
    ok)                    printf '%s' "$G" ;;
    fail|crash|hang|diff)  printf '%s' "$R" ;;
    *)                     printf '%s' "$D" ;;
  esac
}
cell () { # <text> <width> [colour]
  local txt="$1" w="$2" col="${3-}" pad
  pad=$(( w - ${#txt} )); [ "$pad" -lt 0 ] && pad=0
  printf '%s%s%s%*s' "$col" "$txt" "$Z" "$pad" ""
}
row () { # <name> <check> <run> <c> <build> <native> <diagnosis>
  cell "$1" 16
  cell "$2" 7  "$(colour_of "$2")"
  cell "$3" 6  "$(colour_of "$3")"
  cell "$4" 6  "$(colour_of "$4")"
  cell "$5" 7  "$(colour_of "$5")"
  cell "$6" 8  "$(colour_of "$6")"
  printf '%s\n' "$7"
}

# run_prog <timeout> <dir> <stdin-file|""> <cmd...> -- runs in <dir>
run_prog () {
  local t="$1" d="$2" sf="$3"; shift 3
  if [ -n "$sf" ]; then
    (cd "$d" && run_to "$t" "$@" <"$sf" 2>&1)
  else
    (cd "$d" && run_to "$t" "$@" </dev/null 2>&1)
  fi
}

FILES=()
while IFS= read -r line; do FILES+=("$line"); done < <(find "$DIR" -maxdepth 1 -name '*.bend' | sort)
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "no .bend files in $DIR"; exit 0
fi

echo "${B}bend${Z}  $BEND ${D}($("$BEND" version 2>/dev/null | head -1))${Z}"
echo "${B}dir${Z}   $DIR"
[ "$HAVE_CLANG" -eq 0 ] && echo "${Y}note${Z}  clang not found -- C/BUILD/NATIVE skipped"
echo

printf '%s' "$B"; row PROGRAM CHECK RUN C BUILD NATIVE DIAGNOSIS; printf '%s' "$Z"
printf '%s\n' "$(printf '%.0s-' {1..96})"

FAILED=(); DETAIL=()
n_ok=0; n_bad=0
c_run=0; c_c=0; c_build=0; c_native=0; n_err=0

fail_note () { FAILED+=("$1"); DETAIL+=("$2"); n_err=$((n_err+1)); }

for f in "${FILES[@]}"; do
  name="$(basename "$f" .bend)"
  fdir="$(dirname "$f")"
  s_check="-"; s_run="-"; s_c="-"; s_build="-"; s_native="-"; diag=""

  args_line="$(pragma "run-args" "$f")"
  stdin_file="$(pragma "stdin" "$f")"
  expect="$(pragma "expect" "$f")"
  rargs=()
  # shellcheck disable=SC2206
  [ -n "$args_line" ] && rargs=($args_line)
  sf=""
  if [ -n "$stdin_file" ]; then
    case "$stdin_file" in /*) sf="$stdin_file" ;; *) sf="$fdir/$stdin_file" ;; esac
  fi

  # --- CHECK -------------------------------------------------------------
  out="$(run_to "$CHECK_TIMEOUT" "$BEND" "$f" --check-only 2>&1)"; code=$?
  if [ $code -ne 0 ] || ! printf '%s' "$out" | grep -q '^ALL PROOFS CHECK'; then
    s_check="fail"
    diag="$(classify $code "$out")"
    fail_note "$name (check)" "$out"; n_bad=$((n_bad+1))
    row "$name" "$s_check" "$s_run" "$s_c" "$s_build" "$s_native" "$diag"
    continue
  fi
  s_check="ok"; n_ok=$((n_ok+1))

  # --- RUN ---------------------------------------------------------------
  out="$(run_prog "$RUN_TIMEOUT" "$fdir" "$sf" "$BEND" "$f" "${rargs[@]}")"; code=$?
  result="$(printf '%s\n' "$out" | grep -v '^note: no usable GPU' | head -1)"
  if [ $code -ne 0 ]; then
    s_run="fail"; diag="run: $(classify $code "$out")"
    fail_note "$name (run)" "$out"
    row "$name" "$s_check" "$s_run" "$s_c" "$s_build" "$s_native" "$diag"
    continue
  fi
  if [ -n "$expect" ] && [ "$result" != "$expect" ]; then
    s_run="diff"; diag="$result ${D}| expected: $expect${Z}"
    fail_note "$name (run)" "got:      $result"$'\n'"expected: $expect"
    row "$name" "$s_check" "$s_run" "$s_c" "$s_build" "$s_native" "$diag"
    continue
  fi
  s_run="ok"; c_run=$((c_run+1)); diag="$result"

  if [ "$NATIVE" -eq 0 ] || [ "$HAVE_CLANG" -eq 0 ] || has_pragma "skip-native" "$f"; then
    row "$name" "$s_check" "$s_run" "$s_c" "$s_build" "$s_native" "${diag:0:60}"
    continue
  fi

  # --- C -----------------------------------------------------------------
  cfile="$WORK/$name.c"
  cout="$(run_to "$CHECK_TIMEOUT" "$BEND" "$f" -o "$cfile" 2>&1)"; code=$?
  if [ $code -ne 0 ] || [ ! -s "$cfile" ]; then
    s_c="fail"; diag="$result ${D}| C: $(classify $code "$cout")${Z}"
    fail_note "$name (C)" "$cout"
    row "$name" "$s_check" "$s_run" "$s_c" "$s_build" "$s_native" "$diag"
    continue
  fi
  s_c="ok"; c_c=$((c_c+1))

  # --- BUILD -------------------------------------------------------------
  mkdir -p "$WORK/bin"; bin="$WORK/bin/$name"   # no extension: a native binary
  bout="$(run_to "$CHECK_TIMEOUT" "$BEND" "$f" -o "$bin" 2>&1)"; code=$?
  if [ $code -ne 0 ] || [ ! -x "$bin" ]; then
    s_build="fail"
    diag="$result ${D}| build: $(printf '%s\n' "$bout" | grep -m1 'error' || classify $code "$bout")${Z}"
    fail_note "$name (build)" "$bout"
    row "$name" "$s_check" "$s_run" "$s_c" "$s_build" "$s_native" "$diag"
    continue
  fi
  s_build="ok"; c_build=$((c_build+1))

  # --- NATIVE ------------------------------------------------------------
  rout="$(run_prog "$RUN_TIMEOUT" "$fdir" "$sf" "$bin" "${rargs[@]}")"; code=$?
  native="$(printf '%s\n' "$rout" | grep -v '^note: no usable GPU' | head -1)"
  if [ $code -eq 124 ]; then
    s_native="hang"; diag="$result ${D}| native: timeout${Z}"
    fail_note "$name (native)" "$rout"
  elif [ $code -ge 128 ]; then
    s_native="crash"; diag="$result ${D}| native: signal $((code-128))${Z}"
    fail_note "$name (native)" "$rout"
  elif [ $code -ne 0 ]; then
    s_native="fail"; diag="$result ${D}| native: exit $code${Z}"
    fail_note "$name (native)" "$rout"
  elif [ "$native" != "$result" ]; then
    s_native="diff"; diag="$result ${D}| native: ${native:0:40}${Z}"
    fail_note "$name (native)" "bend:   $result"$'\n'"native: $native"
  else
    s_native="ok"; c_native=$((c_native+1)); diag="${result:0:60}"
  fi
  row "$name" "$s_check" "$s_run" "$s_c" "$s_build" "$s_native" "$diag"
done

echo
n_tot=$((n_ok+n_bad))
echo "${B}$n_tot programs${Z}  check ${G}$n_ok ok${Z}$([ $n_bad -gt 0 ] && printf ", %s%s failed%s" "$R" "$n_bad" "$Z")  |  run $c_run ok"
if [ "$NATIVE" -eq 1 ]; then
  echo "${D}             C $c_c ok  |  build $c_build ok  |  native $c_native ok${Z}"
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

[ "$n_err" -eq 0 ]
