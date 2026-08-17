# Duck Hunt: issues and unexpected behavior

## Summary

Duck Hunt checks, compiles, and runs without changes to the Bend3 compiler or
runtime. Two authoring approaches did not work:

1. normal checking cannot resolve the HTTP continuation's later server-loop
   definition; and
2. an expression-style `if condition { a } else { b }` is rejected by the
   parser.

The demo uses the existing `--no-halt` whole-book mode for the first issue and
ordinary `match` helpers for the second. Browser audio also requires an
explicit user gesture, and the supplied client reports hit geometry to the
server.

## Reproduction identity

- Bend npm package version: `0.1.0`
- Bend3 compiler/base revision:
  `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Unmodified repository baseline used to build the demo:
  `32eeb601647d477ad1b411e3d00e415150c5f65c`
- Duck Hunt feature baseline:
  `efdc6c4a63bdf1f9e3fea7f798c84b13b2e07a9d`
- Recorded: 2026-07-27

The compiler/base revision is the most recent commit touching `bend-ts/src` or
`base` in the checkout. The feature baseline contains the exact game source
used for the successful checks below. No compiler or runtime source was
modified during implementation or verification.

## Issue: normal checking cannot see the later server loop

### Summary

Running the checker without `--no-halt` reports `u32_serve` as unbound where
`routed_send` continues the stateful HTTP loop. The same production source
checks and compiles with `--no-halt`.

### Detailed reproduction

At the feature baseline, run:

```sh
node bend-ts/src/main.ts gabriel_demos/duck_hunt_web/web_duck_hunt.bend
```

The result is:

```text
NotBound:
- name : u32_serve
Location: routed_send
```

This server shape is shared by other stateful demos. Its one canonical,
isolated reproduction remains
[`mre_mutual_scope.bend`](../../minecraft_web/unexpected_behavior/mre_mutual_scope.bend).

### Demo-side workaround

The build uses the existing whole-book checking option:

```sh
node bend-ts/src/main.ts gabriel_demos/duck_hunt_web/web_duck_hunt.bend --no-halt
```

This is a command-line mode choice, not a compiler patch.

## Issue: expression-style `if` is rejected

### Summary

The parser does not accept a value expression written as
`if condition { value } else { value }`. It reports `expected name` at the
`if` token.

### Detailed reproduction

The isolated source is
[`mre_expression_if.bend`](mre_expression_if.bend). Run:

```sh
node bend-ts/src/main.ts gabriel_demos/duck_hunt_web/unexpected_behavior/mre_expression_if.bend --no-halt
```

Observed output begins:

```text
Syntax:
- error : expected name
Location:
4 |   if 1 > 0 { 1 } else { 0 }
```

### Demo-side workaround

Duck Hunt uses `match`-based helpers such as `u32_high_player` and
`u32_shot_note`. This keeps the conditional logic explicit and accepted by the
current checker.

## Browser constraint: audio needs a user gesture

### Summary

Modern browsers start WebAudio in a suspended state. Sound cannot reliably
begin merely because the page loaded.

### Resolution

**Start hunt** and the sound switch both create or resume the `AudioContext`
inside a direct click or tap handler. Shots, flaps, barks, hit cues, and
jingles are synthesized from oscillators and noise; no media files or external
assets are required.

This is browser autoplay policy, not Bend3 behavior.

## Remaining demo limitations

- Bend owns ammunition, score, bonuses, round qualification, progression, and
  the LAN high score, but the supplied browser reports whether its pixel hit
  test intersected the duck. A custom HTTP client can falsely report a hit.
- Player state is in memory. A clean page exit sends `/leave`, but a browser or
  machine that disappears abruptly leaves a small stale player record until
  the Bend process restarts.
- Automated browser verification proves that the WebAudio graph is unlocked
  and constructed without page errors; it cannot judge audible volume or
  speaker quality.
- Chromium automation on this managed Mac needs process-launch permission.
  The one canonical environment report is in the
  [BendJogos issue log](../../bendjogos_web/unexpected_behavior/README.md#verification-environment-sandboxed-chromium-launch-was-denied).

## Verification

At `efdc6c4a63bdf1f9e3fea7f798c84b13b2e07a9d`:

- both Duck Hunt and the expanded BendJogos source check with `--no-halt`;
- the standalone native binary builds and serves strict JSON;
- three misses exhaust the shells and resolve an escape;
- ten accuracy-band-three hits produce 12,500 points, update the shared high
  score, and advance to round two;
- headless Chromium passes desktop aiming, moving-duck collision, score,
  animation, WebAudio unlock, mobile touch fire, and 390-by-844 layout checks;
  and
- the full Bend3 repository suite passes 506/506, including 150 compiled cases.

## 2026-08-17 retest against upstream `1ebc1acc`

The earlier later-definition scoping failure is fixed. Duck Hunt now checks in
default mode, and it also checks, emits C, builds, and serves HTTP 200 on port
8089 through the package's established `--no-halt` build.

Expression-style braces remain unsupported. With the current parser,
[`mre_expression_if.bend`](mre_expression_if.bend) is rejected at the opening
brace after the condition (the wording is now an `expected ':'`-style syntax
diagnostic rather than the historical `expected name`). `match` remains the
portable source form.
