# Cell Arena: unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Recorded: 2026-07-22

## Issue: compiled IO main was rejected

### Summary

An otherwise valid `main() -> IO<U32>` compiled to a program that stopped with
`error: main: expected a word` before opening its TCP listener.

### Details and reproduction

The checker wrapped the application head in `Ann(x, T)`, while `io_main` in
`bend-ts/src/prep.ts` tested the wrapped term directly for `IO::IO`. Compile an
IO demo from a Bend3 revision without the local `io_main` fix and run it:

```sh
node bend-ts/src/main.ts gabriel_demos/agar_web/web_agar.bend --no-halt -o /tmp/web_agar
/tmp/web_agar
```

### Resolution

`io_main` now strips transparent annotations before the identity test. All
compiled IO demos depend on that correction.

## Issue: the server loop requires `--no-halt`

### Summary

The structurally valid state-carrying TCP accept loop is intentionally
long-lived, so Bend3's termination checker cannot prove it terminates.

### Resolution

Build this server with `--no-halt`. This disables the termination proof; it
does not change the runtime behavior.

## Issue: composing both realtime arenas duplicated the clock effect

### Summary

Cell Arena and Snake Arena originally declared separate `now_ms` effects.
Importing both into BendJogos created duplicate effect constructors.

### Resolution

The effect has one home in `gabriel_demos/Clock.bend`; both arenas import it.

