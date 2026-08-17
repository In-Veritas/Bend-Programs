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
