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

## Issue: the static page requires the repository-root working directory

### Summary

The route reads `gabriel_demos/elements_web/index.html` at request time. Running
the binary from another directory makes that relative path fail.

### Resolution

Launch it from the repository root. A future standalone package would embed or
resolve assets relative to the executable.

## Issue: long-running phase values reduce approximation reliability

### Summary

The scene's hand-written sine approximation expects a bounded phase. Allowing
the frame counter to grow forever eventually violates that assumption.

### Resolution

The frame index wraps at `190400`, corresponding to approximately
`1000 * 2π` seconds.

