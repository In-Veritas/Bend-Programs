# Bar Bench Web: unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Recorded: 2026-07-22

## Issue: compiled IO main was rejected

### Summary

The generated server previously exited with `error: main: expected a word`.

### Resolution

The preparation pass now removes transparent annotations before recognizing
the `IO::IO` main application.

## Issue: Bend3 has no browser compilation target

### Summary

The first web interpretation expected Bend to emit browser JavaScript. Bend3
instead compiles the native server.

### Resolution

The Bend program owns HTTP routing and physics. A small static browser canvas
only rasterizes the command stream returned by the server.

