# `case _ []:` in a multi-scrutinee match is a parse error

## Description

In a `match a b:` arm, the pattern pair `_ []` (wildcard, then the empty
list literal) does not parse: the parser reads `_ [` as the start of an index
or list term and fails at `]`. `[] _` and `_ Nil{}` both work, so the empty-list
pattern is only refused right after `_`.

Expected: `case _ []:` matches any first value with an empty list, like
`case _ Nil{}:`. Actual: SOME PROOFS FAIL with a parse error.

## Reproduce

```sh
bend mre.bend
```

## Output

```
SOME PROOFS FAIL
Error:
- expected : a term
- observed : ']'
Location:
6 |       0
7>|     case _ []:
  |             ^
8 |       1
```

With `case _ Nil{}:` instead, `bend mre.bend` prints `7`.

## Environment

- bend 2.0.40
- Linux x86_64
- Ubuntu clang version 21.1.8

## Workaround used in the port

Write `case _ Nil{}:`.

## Hit by

`Bend2/water_movement/main.bend` (`Wm.pviews`).
