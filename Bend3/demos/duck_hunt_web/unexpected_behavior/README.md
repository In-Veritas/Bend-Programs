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
