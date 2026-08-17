# Block World: issues and unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Block World feature baseline: `39e4763629a8ed380aafddd8f28ee199c773cfcd`
- Recorded: 2026-07-22

The feature baseline contains the exact source and compiler used for these
observations. No Bend3 compiler files were changed while building or testing
Block World.

## Issue: the mutually recursive server loop needs whole-book scoping

### Summary

The HTTP server is intentionally long-lived. Its accept, parse, route, send,
and next-accept functions form a mutual-recursion cycle. With Bend3's default
termination checking, a call to the later `u32_serve` definition is reported
as unbound. `--no-halt` both disables the termination proof and widens name
resolution to the whole book, so the same unchanged source checks and builds.

### Full-demo reproduction

From the repository root at the feature baseline:

```sh
git checkout 39e4763629a8ed380aafddd8f28ee199c773cfcd
node bend-ts/src/main.ts gabriel_demos/minecraft_web/web_minecraft.bend
```

The command exits with status 1:

```text
NotBound:
- name : u32_serve
Context:
- game     : Game
- response : HTTP::Response
- server   : U32
- conn     : HTTP::Conn
- sent     : Result::Result(U32)
- closed   : U32
Location: routed_send
568 |         closed : U32 <- HTTP::conn_close(conn)
569>|         u32_serve(server, game)
570 |
```

After returning to a revision containing this issue package, the same behavior
can be reproduced without the game using
[`mre_mutual_scope.bend`](mre_mutual_scope.bend):

```sh
node bend-ts/src/main.ts gabriel_demos/minecraft_web/unexpected_behavior/mre_mutual_scope.bend
node bend-ts/src/main.ts gabriel_demos/minecraft_web/unexpected_behavior/mre_mutual_scope.bend --no-halt --eval
```

The first command reports `NotBound: u32_second`; the second succeeds and
prints `0`.

### Status and approach

This is a documented language mode distinction, not a locally patched
compiler defect. `GUIDE.md` states that `--no-halt` admits mutual recursion and
enables whole-book scoping. The build script therefore uses `--no-halt`, and
the failing baseline remains available for independent reproduction.

## Observation: composing the release binary is expensive to optimize

### Summary

The standalone Block World binary builds successfully, but importing it into
the already unified hub produced roughly 24 MB of generated C. On the recorded
machine, the canonical `clang -O3` stage remained CPU-active for about 34
minutes before completing. Bend checking and C emission were quick.

### Status

The build completed without a compiler error and the resulting binary passed
the live route tests. No second compiler path, reduced optimization mode, or
runtime workaround was added. This is recorded as a composition cost rather
than treated as a correctness failure.

## Demo limitations, not Bend3 failures

- The authoritative 24×24 world and four player slots live in memory and
  reset with the server.
- Terrain is represented as editable columns rather than an unbounded 3D
  chunk database.
- Browser player identities are random session IDs and are separate from the
  BendJogos account system.

## 2026-08-17 retest against upstream `1ebc1acc`

The old name-resolution failure is fixed: default checking now resolves later
and mutually recursive definitions. The production Block World source checks
in default mode and also builds in its existing `--no-halt` workflow.

That fix exposed a different checker problem. The updated
[`mre_mutual_scope.bend`](mre_mutual_scope.bend) makes the two-function cycle
reachable from `main`; default checking still exits successfully even though
the program cannot terminate. Do not run it with `--eval`. The current
reproduction is:

```sh
bun bend-ts/src/bend.ts gabriel_demos/minecraft_web/unexpected_behavior/mre_mutual_scope.bend
```

This is now a mutual-termination soundness issue, not a scoping issue. The
historical section above is retained because it records the earlier compiler's
observable behavior.
