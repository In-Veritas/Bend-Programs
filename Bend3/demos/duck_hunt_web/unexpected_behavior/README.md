# Duck Hunt: Bend3 behavior

## Reproduction revisions

- Bend package version: `0.1.0`
- Historical compiler/base revision:
  `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Duck Hunt feature baseline: `efdc6c4a63bdf1f9e3fea7f798c84b13b2e07a9d`
- Current retest revision: `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`

No Bend compiler or runtime source was modified for this demo.

## Historical issue: normal checking could not see the later server loop

At the feature baseline, checking without `--no-halt` reported `u32_serve` as
unbound where the HTTP response continuation returned to the stateful server
loop. The same source checked and compiled with `--no-halt`.

The server shape has one canonical isolated reproduction in
[`mre_mutual_scope.bend`](../../minecraft_web/unexpected_behavior/mre_mutual_scope.bend).
At current revision `1ebc1acc`, later-definition scoping is fixed and Duck Hunt
checks in default mode.

## Issue: expression-style `if` is rejected

The parser does not accept a value expression written as
`if condition { value } else { value }`. The isolated source is
[`mre_expression_if.bend`](mre_expression_if.bend).

```sh
bun bend-ts/src/bend.ts gabriel_demos/duck_hunt_web/unexpected_behavior/mre_expression_if.bend
```

At `1ebc1acc`, the parser reports an `expected ':'`-style syntax diagnostic at
the opening brace. `match` remains the accepted source form.

## Retest on Bend 2.0.40 (2026-11-23)

Retested with the released Bend 2.0.40 binary and the bendlang/bend source
checkout at 6b806192 (both report `bend 2.0.40`).

- Later-definition scoping / `--no-halt`: obsolete. Defs may only call defs
  above them (by design), the server loop lives in `../HTTP.bend`'s
  fuel-bounded `HTTP.serve`, and the port prints ALL PROOFS CHECK with no
  `@unsafe` and no flags.
- `mre_expression_if.bend`: still rejected. This is by design, not a bug:
  `bend guide` says "there is no `if` syntax yet. Use `match` on `True{}` and
  `False{}` instead." The errors are not very helpful, because `if` parses
  as a plain identifier:

  ```text
  $ bend Bend3/demos/duck_hunt_web/unexpected_behavior/mre_expression_if.bend
  SOME PROOFS FAIL
  Error:
  - expected : 'def', 'type' or 'law'
  - observed : '1'
  Location:
  4>|   if 1 > 0 { 1 } else { 0 }
    |      ^
  ```

  With `import Base` and `if U32.is_gt(1, 0) { 1 } else { 0 }` the error is
  `expected '=' observed '{'`, and the indented `if c:` / `else:` form gives
  `expected '=' observed ':'`. The port uses `match` on a `Bool` parameter or
  `Bool.pick(T, cond, a, b)` (which evaluates both sides) instead.
