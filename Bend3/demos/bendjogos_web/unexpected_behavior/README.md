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
