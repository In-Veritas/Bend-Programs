# BendJogos Web Hub: Bend3 behavior

## Reproduction revisions

- Bend3 package version: `0.1.0`
- Historical compiler/base revision:
  `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Current retest revision: `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`

## Issue: parent-relative modules broke C-effect lookup

### Summary

The Bend loader found a parent-relative `.bend` module, but `book_eff` removed
the first two characters from its import identifier. Importing `../Clock` made
`../effs/now_ms.c` resolve as `.//effs/now_ms.c` under the wrong directory.

### Minimal reproduction

Import a parent module which itself declares a C-bodied effect, then check or
compile the importing program.

### Resolution

`bend-ts/src/bend.ts` preserves the `../` prefix while routing the effect
through the local-file reader.

## Issue: duplicated effect declarations collided during composition

Snake Arena and Cell Arena originally declared separate realtime clock
effects. Importing both into one Bend book produced duplicate constructors.
The clock now has one declaration in `gabriel_demos/Clock.bend`, which both
modules import.

## Issue: an effect name collided with a generated runtime C symbol

Naming the shared effect `now_ms` generated `io_now_ms`, which collided with a
runtime helper of the same name. Bend checking succeeded, but native C
compilation reported conflicting declarations. The effect is now named
`clock_now_ms`, which generates `io_clock_now_ms`.

## Current behavior: import aliases do not namespace declarations

At `1ebc1acc`, import aliases are tooling metadata rather than language
namespaces. Directly importing all standalone games merges declarations into
one book and produces collisions such as `Game` and `clamp0`.
`generate_modules.mjs` therefore derives hub-private dotted declaration names
while preserving independently compilable standalone sources.

## Retest on Bend 2.0.40

Retested with Bend 2.0.40 (latest bendlang/bend source, HEAD 6b806192) on
Linux x86_64, Ubuntu clang 21.1.8, while porting the hub.

- Parent-relative module C-effect lookup: no longer applicable. The hub has no
  custom C effect; `Clock.bend` wraps Base's `IO.now`, and every effect used
  (TCP, files, random, `Process.run`) is in Base.
- Duplicated effect declarations / `io_now_ms` symbol collision: no longer
  reproduce. Snake and Cells both import the one `../Clock.bend` module and
  the effect lives in Base.
- Import aliases do not namespace declarations: fixed in Bend 2.0.40. An
  alias is a namespace (`Tic.Game`, `Snake.Game`, `HTTP.Request` shared by
  every module that imports `../HTTP.bend`), so the hub imports the
  standalone demos directly; `modules/` was deleted and
  `generate_modules.mjs` is a no-op.
- New: with all fourteen game states unboxed side by side, the native build
  failed with `Error: an arity over 247` and no location after a successful
  check (`bugs/native-arity-over-247-wide-records`). Workaround: the `Held`
  self-referential box around each `Platform` field.
- New, observation: the native hub build peaks at about 15.7 GB RSS and takes
  1 min 19 s wall time (`/usr/bin/time -v`, under `nice -n 19`).
