# Elements Web: unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Recorded: 2026-07-22

## Issue: compiled IO main was rejected

### Summary

Before the local preparation fix, the server stopped with
`error: main: expected a word`.

### Resolution

`io_main` now strips the checker's transparent annotation before identifying
the `IO::IO` reference.

## Issue: Bend3 does not compile directly into the browser

### Summary

There is no Bend-to-JavaScript browser target in this checkout.

### Resolution

The Bend executable is the HTTP and simulation server. The browser page is a
thin canvas presenter for the returned draw commands.


## Retest on Bend 2.0.40 (2026-11-23)

Also rechecked with the bendlang/bend source at 6b806192; no difference.

- **compiled IO main was rejected**: does not reproduce.
- **no direct browser compilation**: Bend now has JS targets, but the demo
  keeps its server-owned scene. Imports are namespaces now, so the scene is
  imported from `../elements/elements.bend` instead of being a copy.
- As with bar_bench_web, the checked-in page fetched `/elements/frame/...`;
  the port's `route` accepts the path with and without that prefix.
