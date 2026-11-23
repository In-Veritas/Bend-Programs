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


## Retest on Bend 2.0.40 (2026-11-23)

Also rechecked with the bendlang/bend source at 6b806192; no difference.

- **compiled IO main was rejected**: does not reproduce.
- **no browser compilation target**: Bend now has `-o file.js` / `.mjs` and
  `bend page.html -o dist`, but the demo keeps its design (the Bend server owns
  routing and physics; the page only rasterizes).
- Found while porting, not a Bend bug: the checked-in `index.html` fetched
  `/bar/frame/...` (the hub's prefix), which the old standalone server
  answered with 404. The port's `route` accepts both `/frame/...` and
  `/bar/frame/...`.
