# Block World: Bend3 behavior

## Reproduction revisions

- Bend3 package version: `0.1.0`
- Historical compiler/base revision:
  `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Block World feature baseline: `39e4763629a8ed380aafddd8f28ee199c773cfcd`
- Current retest revision: `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`

No Bend3 compiler or runtime file was modified for this demo.

## Historical issue: the mutually recursive server loop needed whole-book scoping

At the feature baseline, the HTTP response continuation called `u32_serve`,
which was declared later in the file. Default checking reported the name as
unbound. The same source checked with `--no-halt`, which enabled whole-book
scoping in addition to disabling the termination proof.

The isolated reproduction is [`mre_mutual_scope.bend`](mre_mutual_scope.bend).
At the historical baseline, default checking reported `NotBound: u32_second`,
while `--no-halt --eval` succeeded.

## Current issue: reachable mutual nontermination is accepted

At current revision `1ebc1acc`, later-definition scoping is fixed. The updated
MRE makes the two-function cycle reachable from `main`; default checking still
exits successfully even though the program cannot terminate. Do not evaluate
the reproduction.

```sh
bun bend-ts/src/bend.ts gabriel_demos/minecraft_web/unexpected_behavior/mre_mutual_scope.bend
```

This is a mutual-termination soundness issue rather than the historical
scoping issue.

## Retest on Bend 2.0.40 (2026-11-23)

Tested with the released `bend 2.0.40` binary and with the bendlang/bend
source checkout at `6b806192` (`bun bend2/main.ts`, also reporting 2.0.40);
both behave the same.

- **Later-definition scoping (historical):** no longer an issue by design.
  Defs are checked in file order; a call to a def written below is rejected
  with `expected: a def whose body is implemented before the def is used`.
  There is no `--no-halt`/whole-book mode any more; `@unsafe` is the only
  opt-out and it is reported (`SOME PROOFS FAIL ... defs that depend on
  @unsafe`).
- **Reachable mutual nontermination accepted (current issue at `1ebc1acc`):**
  fixed. `mre_mutual_scope.bend` as saved has no `import Base`, so 2.0.40
  stops earlier with `expected: a defined name / observed: U32`. With
  `import Base` added, the two-def cycle is rejected
  (`SOME PROOFS FAIL`, `u32_second` must be implemented before use); marking
  both defs `@unsafe` makes the check report them instead of accepting
  silently. Nothing to move to `bugs/`.
- The port itself needs neither: the server loop is `../HTTP.bend`'s
  Nat-fuelled `HTTP.serve`, and the file checks with ALL PROOFS CHECK and no
  `@unsafe`.
