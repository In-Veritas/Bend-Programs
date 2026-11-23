# Errors, bugs, and problems found

This directory is the central triage index for behavior discovered while
building and testing the programs in this repository. Its purpose is to turn a
confirmed Bend defect into a small upstream regression test or pull request
without mixing compiler issues with application bugs or expected language
constraints.

Package-local `unexpected_behavior/` directories remain the canonical homes
for reproductions. This index records their upstream status and links to them;
it does not replace or duplicate those files.

## Current upstream candidates

| Status | Implementation | Finding | Reproduction |
| --- | --- | --- | --- |
| Confirmed on latest upstream | Bend3 `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb` | Default termination checking accepts a reachable two-function nonterminating cycle | [PR-ready report](bend3_reachable_mutual_recursion/README.md) |
| Reproduced on latest upstream | Bend 2.0.38 `de26a917085a249786f185d20233f107462285f1` | `--verdict` rejects structurally decreasing affine IO recursion across exclusive branches that the ordinary checker accepts | [Minimized report](bend_verdict_affine_branch/README.md) |

The Bend3 mutual-recursion case was reproduced on 2026-10-22 in a clean
detached worktree of the fetched `origin/main` revision. The full BendJogos hub
also compiled successfully from the same revision. The Bend2 verdict mismatch
was minimized independently on 2026-10-25; it is ready for upstream triage but
does not yet identify whether translation or kernel quantity accounting should
change.

## Historical cases requiring a fresh port

The following backend failures were real on the recorded Bend2 Core revision,
but their minimized sources use syntax that the current public Bend 2.0.38
parser no longer accepts. They must be ported and reproduced before opening a
new upstream issue or PR:

- [`U32.zero` / `U32.one` C emission](../Bend2%20Core/unexpected_behavior/README.md),
  last reproduced at `c5d69a14608b93896b5046e310d501903235d6c8`.
- [Erased proof binder escaping a compiled continuation](../Bend2%20Core/demos/bendy_birds/unexpected_behavior/README.md),
  last reproduced at `c5d69a14608b93896b5046e310d501903235d6c8`.

The separate legacy `bend2-core` checkout is at its own current `origin/main`,
`87355989791e12e0f29026ea1f65dc344290c24c` (2.0.16), but these old MREs also
need syntax migration there. A parser rejection of stale syntax is not evidence
that the original backend bug remains.

## Known problems that are not Bend defects

These findings belong in application documentation, benchmarks, or operational
notes, not in Bend's upstream issue tracker:

- the ZeroTier timeout to BendJogos: the process listens on all interfaces and
  returns HTTP 200 through the host's ZeroTier address; the remaining fault is
  in the remote peer, route, browser, or ZeroTier flow policy;
- expensive exact global alignment for surviving long-genome candidates in the
  clustering reference implementations: sparse graphs and packed streaming
  removed the former dense/input-memory blockers and threshold banding reduces
  the work, but this remaining cost is an application algorithm choice, not
  compiler memory corruption; the explicit fast mode is approximate;
- the clustering launcher's compiler preference contradicted its README and
  selected legacy `bend2-core` before public `bend`; this application bug was
  fixed on 2026-10-24 and the full fast runs were repeated with Bend 2.0.38;
- the launcher's `--fast` help incorrectly said exact alignment still followed
  its MinHash gate, while long sequences actually use an approximate sketch
  score; the application help was corrected on 2026-10-25;
- expression-style `if` being rejected by Bend3 when `match` is the supported
  source form;
- import aliases not acting as declaration namespaces in Bend3; and
- ports, firewalls, browser policy, long-running service loops, dataset size,
  and test-harness state.

## Toolchain audit

Verified through 2026-10-25:

- public Bend was fast-forwarded from 2.0.37 to current `main` at
  `de26a917085a249786f185d20233f107462285f1` (CLI version 2.0.38,
  `v2.0.38-13-gde26a91`);
- all 27 clustering tests passed on that revision in native C and JavaScript,
  including the pure-score `--verdict` gate;
- Bend3 `origin/main` remains
  `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`; and
- the authored Bend3 checkout was intentionally not merged because it is 35
  commits ahead and 1,603 commits behind upstream and contains working changes.

## Adding a report

Create one subdirectory per independent finding and start from
[`REPORT_TEMPLATE.md`](REPORT_TEMPLATE.md). A report is ready for upstream only
when it has:

1. the exact upstream repository and commit;
2. a minimized source file or a link to its canonical versioned MRE;
3. one deterministic command;
4. expected and actual behavior, including exit status and diagnostics;
5. confirmation that the problem is still present on the latest fetched
   revision; and
6. a proposed regression test that fails before the fix and passes after it.

Do not classify a slow algorithm, unsupported feature, documented syntax rule,
or environment/network failure as a Bend bug.
