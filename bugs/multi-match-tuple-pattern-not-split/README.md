# Multi-scrutinee `case` cannot list two tuple patterns `(a, b) (c, d)`

## Description
In a `match a b:` with two scrutinees, a case whose patterns are two tuple
patterns written with the documented tuple syntax, `case (x, y) (z, w):`, is
rejected with "expected 2 patterns (one per scrutinee)". The parser apparently
reads `(x, y) (z, w)` as a single pattern (an application of the first
parenthesised form to the second). The guide says patterns nest and `(a, b)`
is a tuple, so this should be two patterns.

Expected: the file checks and prints `5`.
Actual: SOME PROOFS FAIL with the error below.

Writing the second pattern as a constructor (`case (x, y) Tuple{z, w}:`, or
`Tuple{x, y} Tuple{z, w}`) works and prints `5`.

## Reproduce
```sh
bend mre.bend
```

## Output
```
SOME PROOFS FAIL
Error:
- expected : 2 patterns (one per scrutinee)
- observed : '(x, y) (z, w)'
Location:
4 |   match a b:
5>|     case (x, y) (z, w):
  |          ^^^^^^^^^^^^^
6 |       U32.add(x, w)
```

## Environment
- bend 2.0.40
- Linux x86_64
- Ubuntu clang version 21.1.8

## Workaround used in the port
Spell the patterns as `Tuple{x, y} Tuple{z, w}`.

## Hit by
`Bend2 Core/programs/transtyping.bend` (`convert.node`).
