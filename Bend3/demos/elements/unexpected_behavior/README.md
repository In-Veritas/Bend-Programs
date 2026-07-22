# Elements: unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Recorded: 2026-07-22

## Issue: compiled IO main was rejected

### Summary

The compiled window demo previously stopped with `error: main: expected a word`.

### Resolution

`io_main` now strips transparent checker annotations before recognizing the
`IO::IO` application.

## Issue: Bend3 has no trigonometric primitive for the scene

### Summary

The four animations require periodic motion, but the pure language surface
used by the demo has no sine primitive.

### Resolution

The demo uses Bhaskara I's approximation plus explicit range reduction. Time
wraps at `1000 * 2π` so the approximation never receives an unbounded phase.

## Issue: Metal compute does not provide window-system integration

### Summary

The GPU target can compute frames but does not create a Cocoa surface or pump
input events.

### Resolution

Pure Bend emits a draw-command list and the C-bodied window effect performs
only presentation and event handling, mirroring the Bar Bench design.

## Issue: one effect source is built in two language modes

### Summary

The CPU build treats `effs/window.c` as C while the Metal build uses
Objective-C and ARC.

### Resolution

The bridge macros and runtime-created Cocoa identifiers keep the single effect
source valid in both modes.

