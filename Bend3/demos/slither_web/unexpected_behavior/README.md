# Snake Arena: unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Recorded: 2026-07-22

## Issue: compiled IO main was rejected

### Summary

Before the local `io_main` correction, the compiled server exited with
`error: main: expected a word` instead of opening its listener.

### Details

The checker produced an annotated application head and the preparation pass
failed to see the `IO::IO` reference through that transparent wrapper.

### Resolution

`bend-ts/src/prep.ts` now strips transparent annotations before recognizing an
IO main.

## Issue: the accept loop requires `--no-halt`

### Summary

The recursive server loop is deliberately non-terminating and is not accepted
by the termination checker.

### Reproduction

```sh
node bend-ts/src/main.ts gabriel_demos/slither_web/web_slither.bend -o /tmp/web_slither
```

### Resolution

Compile the server with `--no-halt`.

## Issue: composing both realtime arenas duplicated the clock effect

### Summary

Snake Arena and Cell Arena originally owned independent effects with the same
purpose. Their constructors collided when both modules were imported by the
unified server.

### Resolution

Both demos now import the single effect declared by `gabriel_demos/Clock.bend`.

