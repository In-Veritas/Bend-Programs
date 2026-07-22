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

## Issue: a GPU backend does not create an OS window

### Summary

Compiling for Metal creates a compute context, not a Cocoa window or event
loop. Treating the GPU target as a presenter left the demo headless.

### Resolution

The pure Bend program emits draw commands. A C-bodied IO effect in
`effs/window.c` owns the Cocoa window, presentation, and input events.

## Issue: one window effect must compile as both C and Objective-C

### Summary

The CPU recipe compiles the effect as C, while the Metal recipe compiles the
same source as Objective-C with ARC. Objective-C-only declarations broke the
CPU rendering of the same design.

### Resolution

The effect uses the `WIN_ID` bridge and runtime-built run-loop strings so one
source compiles in both recipes.

## Issue: negative drawing coordinates do not fit `U32`

### Summary

The flat draw-command stream uses `U32`, but animation geometry can move above
the viewport and needs negative y coordinates.

### Resolution

The pure side adds a documented `+1000` bias; the presenter removes it. This
keeps one command protocol without adding a second signed representation.

