# Bar Bench: unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Recorded: 2026-07-22

## Issue: compiled IO main was rejected

### Summary

The terminal and window variants previously failed at startup with
`error: main: expected a word`.

### Resolution

The `io_main` preparation step now strips the transparent checker annotation
before recognizing `IO::IO`.

## Issue: negative drawing coordinates do not fit `U32`

### Summary

The flat draw-command stream uses `U32`, but animation geometry can move above
the viewport and needs negative y coordinates.

### Resolution

The pure side adds a documented `+1000` bias; the presenter removes it. This
keeps one command protocol without adding a second signed representation.

## Retest on Bend 2.0.40 (2026-11-23)

Also rechecked with the bendlang/bend source at 6b806192 (`bend` running
`bend2/main.ts`); no difference from the 2.0.40 binary was seen for these
files.

- **compiled IO main was rejected**: does not reproduce. `main() -> IO(Unit)`
  builds and runs for both front-ends.
- **negative drawing coordinates do not fit `U32`**: still a property of the
  design, not a bug; the +1000 bias is kept, and `../CommandGFX.bend` now
  removes it while building the `Image`.
- New, not a Bend bug: the old IO-loop chain (`push -> push_next -> push`,
  `ring -> ring_next -> ring`) is mutual recursion, which Bend 2.0.40 forbids;
  it became the pure state machine in `Bench.bend` (`step`/`pose`), driven by
  Nat-fuel loops (terminal) or `App.run` (window).
- Genuine issue hit: with the default GPU, the window build is 5-10x slower
  per frame (`bugs/app-run-cuda-default-3x-slower`); run it with
  `+RTS --gpu off -RTS`.
