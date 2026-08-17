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

