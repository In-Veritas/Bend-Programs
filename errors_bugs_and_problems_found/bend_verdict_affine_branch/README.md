# `--verdict` rejects affine IO recursion accepted by the Bend checker

## Classification

- Status: reproduced on latest public checkout; ready for upstream triage
- Component: Bend2 `--verdict` translation / BendTT quantity checking
- Upstream repository: `bendlang/bend`
- Upstream commit: `de26a917085a249786f185d20233f107462285f1`
- Version: Bend 2.0.38, reproduced 2026-10-25

## Minimal reproduction

From the public Bend checkout:

```sh
bun bend2/main.ts ../Bend-Programs/errors_bugs_and_problems_found/bend_verdict_affine_branch/affine_file_branch.bend --check-only
bun bend2/main.ts ../Bend-Programs/errors_bugs_and_problems_found/bend_verdict_affine_branch/affine_file_branch.bend --verdict
```

## Expected behavior

Both commands should accept the structurally decreasing recursion. Each branch
uses the affine `File` exactly once: it either recurses directly or writes and
passes the returned file to the recursive continuation.

## Actual behavior

The ordinary checker exits 0 with `ALL PROOFS CHECK`. `--verdict` exits 1:

```text
In walk:
affine live code, calls that descend
Sorry - this is a mismatch between the TypeScript implementation, and the formalized BendTT kernel.
```

The same mismatch prevented a kernel verdict for the clustering index because
its imported output path has the same branch-and-write shape. Removing either
branch makes the minimized file pass `--verdict`.

## Upstream change

Add the minimized source as a gate requiring checker/verdict agreement, then
inspect how the safe translator accounts for the affine value captured by
exclusive lambda-map branches around a descending call. This report does not
claim which side of the mismatch is semantically correct.

## Local workaround

There is no equivalent workaround for code that must optionally write while
threading one affine file. The clustering laws still pass the ordinary checker;
their documentation therefore does not claim a BendTT kernel verdict.
