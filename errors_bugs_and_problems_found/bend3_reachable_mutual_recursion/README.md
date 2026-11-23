# Bend3 accepts reachable mutual nontermination in default mode

## Classification

- Status: reproduced and ready for an upstream regression test
- Component: termination checker
- Upstream repository: `VictorTaelin/bend3`
- Upstream commit: `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`
- Reproduced: 2026-10-22 in a clean detached worktree

## Minimal reproduction

The canonical minimized source is
[`mre_mutual_scope.bend`](../../Bend3/demos/minecraft_web/unexpected_behavior/mre_mutual_scope.bend).
It contains a reachable cycle:

```bend
def u32_first(x: U32) -> U32:
  u32_second(x)

def u32_second(x: U32) -> U32:
  u32_first(x)

def main() -> U32:
  u32_first(0)
```

From a clean Bend3 checkout with this repository's `Bend3/demos` directory
available as `gabriel_demos`, run:

```sh
bun bend-ts/src/bend.ts \
  gabriel_demos/minecraft_web/unexpected_behavior/mre_mutual_scope.bend
```

Do not evaluate the program: the reproduction is intentionally nonterminating.

## Expected behavior

Default checking should reject the reachable mutually recursive strongly
connected component because neither call makes a structural decrease. An
explicit termination-disabled mode may accept it, but that mode was not used.

## Actual behavior

The command exits with status 0 and emits no diagnostic. Both function names
are resolved correctly, so this is no longer the historical later-definition
scoping failure.

## Proposed upstream regression

Add the source as a negative termination test and require default checking to
fail. A companion positive test should retain mutually recursive functions
whose cycle has a proven structural decrease. The implementation fix should be
made in the termination analysis of mutually recursive strongly connected
components, not in the parser or name resolver.

## Local workaround

Long-lived server loops are intentionally built with `--no-halt`. Pure code
that is expected to terminate must not rely on the current acceptance of an
unchecked mutual cycle.
