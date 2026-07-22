# BendJogos Web Hub: issues and unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Unified native binary baseline: `0ec035d`
- Recorded: 2026-07-22

## Issue: six independent servers prevented a coherent hub

### Summary

The first platform started separate binaries across ports `8080` through
`8090`. Routes needed different origins, firewall configuration expanded, and
game and social state could not share one owner.

### Resolution

`web_bendjogos.bend` imports the game modules, owns every state value, and
serves every route from one Bend process on port `8090`.

## Issue: parent-relative modules broke C-effect lookup

### Summary

The Bend loader found a parent-relative `.bend` module, but `book_eff` removed
the first two characters from its import identifier. Importing `../Clock` made
`../effs/now_ms.c` resolve as `.//effs/now_ms.c` under the wrong directory.

### Minimal reproduction

Import a parent module which itself declares a C-bodied effect, then check or
compile the importing program.

### Resolution

`bend-ts/src/bend.ts` preserves the `../` prefix while routing the effect
through the local-file reader.

## Issue: duplicated clock effects collided during composition

### Summary

Snake Arena and Cell Arena each declared their own realtime clock effect. They
worked alone but produced duplicate constructors when imported together.

### Resolution

The clock has one home in `gabriel_demos/Clock.bend`.

## Issue: an effect name collided with a generated runtime C symbol

### Summary

Naming the shared effect `now_ms` generated `io_now_ms`, which collided with
the runtime's existing helper of the same name. Bend type-checking succeeded;
the native C compiler reported conflicting declarations.

### Resolution

The effect is named `clock_now_ms`, producing `io_clock_now_ms`. A native build,
not only a Bend check, is required when adding C-bodied effects.

## Issue: filtered JSON arrays emitted a leading comma

### Summary

The initial social emitters returned invalid JSON such as
`[,{"name":"alice"}]` when a filtered array became non-empty. Empty arrays
looked correct and allowed shallow tests to pass.

### Resolution

The emitters explicitly track whether an included item is the first. The
two-account acceptance test parses every response with `JSON.parse` and covers
friend requests, acceptance, presence, chat, and invitations.

## Issue: the combined generated C is expensive to optimize

### Summary

The unified source checks and emits C quickly, but the single `clang -O3` build
is substantially larger and slower than any individual demo build.

### Status

This is an observed cost of intentionally producing one native binary. The
runtime was not complicated to compensate; the build script remains the
canonical build path.

## Limitation: social state is intentionally volatile

Accounts, sessions, friendships, messages, invitations, and presence are held
in the server's immutable state value and disappear when the process restarts.
This is demo scope, but it is externally visible and must not be mistaken for
persistent account storage.

