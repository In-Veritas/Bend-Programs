# Tic-tac-toe: unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Recorded: 2026-07-22

## Issue: compiled IO main was rejected

### Summary

The compiled TCP server previously stopped with `error: main: expected a word`.

### Cause and resolution

`io_main` did not look through the checker's transparent annotation around the
application head. The preparation pass now strips that wrapper before testing
for `IO::IO`.

## Issue: the state-carrying server loop requires `--no-halt`

### Summary

The accept loop carries the immutable `Game` state forever, which cannot have
a termination proof.

### Resolution

Compile with `--no-halt`, as shown in the demo README.

## Issue: HTTP keep-alive blocked the second player

### Summary

One browser could retain the only connection while the sequential accept loop
waited for another request on it, preventing the other player from polling.

### Details

This is an interaction between HTTP/1.1 keep-alive and a deliberately
sequential Bend server, rather than a game-state bug.

### Resolution

Each polling response explicitly uses `Connection: close`, so the loop returns
to `TCP::accept` after every request.

