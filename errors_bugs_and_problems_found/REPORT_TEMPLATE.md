# Short finding title

## Classification

- Status: suspected / reproduced / ready for upstream / fixed upstream
- Component: parser / checker / termination / evaluator / C backend / JS backend / runtime / Base
- Upstream repository:
- Upstream commit:
- Host and tool versions:

## Minimal reproduction

Link to the canonical versioned MRE or place a minimized `.bend` file beside
this report.

```sh
# One deterministic command, run from a stated working directory.
```

## Expected behavior

State the language or backend invariant that should hold.

## Actual behavior

Record the exit status and the shortest complete diagnostic or wrong result.
Do not include secrets, unrelated logs, or generated binaries.

## Cross-checks

- Does it reproduce in a clean checkout of the latest upstream revision?
- Does it affect checking, evaluation, C, JavaScript, or more than one backend?
- Does the same source work when reduced or when an equivalent valid form is
  used?
- Is it absent from the documented language restrictions?

## Upstream change

Describe the smallest regression test and likely implementation boundary. Do
not claim a root cause until the relevant compiler/runtime code confirms it.

## Local workaround

Document any semantics-preserving workaround separately from the proposed fix.
