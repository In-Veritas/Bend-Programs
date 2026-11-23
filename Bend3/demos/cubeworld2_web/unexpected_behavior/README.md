# CubeWorld 2: Bend3 behavior

## Reproduction revisions

- Bend package version: `0.1.0`
- Historical compiler/base revision:
  `ffa2411e9e0bd1275150b07f627c3686a145632d`
- CubeWorld 2 feature baseline: `9cce1a25fcda08e1857e53140fdeb77a17564e9d`
- Current retest revision: `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`

## Historical issue: normal checking could not resolve the later server loop

At the feature baseline, the HTTP continuation called `u32_serve`, which was
declared later in the same file. Default checking reported the name as
unbound, while the identical source checked and compiled with `--no-halt`.
That option enabled whole-book checking for the mutually recursive server
shape.

The language behavior has one canonical isolated reproduction in
[`mre_mutual_scope.bend`](../../minecraft_web/unexpected_behavior/mre_mutual_scope.bend).
No Bend compiler or runtime source was changed for the demo.

At current revision `1ebc1acc`, later-definition scoping is fixed. The shared
MRE now records the remaining mutual-termination behavior.

## Retest on Bend 2.0.40 (2026-11-23)

Tested with the released `bend 2.0.40` binary and with the bendlang/bend
source checkout at `6b806192`. The forward-reference server cycle no longer
exists: the port uses the shared `../HTTP.bend` toolkit (`HTTP.serve`, a
Nat-fuelled loop), so there is no later-defined `u32_serve` to call and no
`--no-halt` mode is needed (2.0.40 has none; defs are checked in file order).
The shared MRE
[`mre_mutual_scope.bend`](../../minecraft_web/unexpected_behavior/mre_mutual_scope.bend)
is now rejected (see its retest note there); the soundness issue does not
reproduce. The port checks with ALL PROOFS CHECK and no `@unsafe`.
