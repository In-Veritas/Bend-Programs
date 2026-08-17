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
