# Unexpected behavior and limitations

- Bend2 Core's JavaScript emitter invokes and prints `main` immediately.
  `build.mjs` verifies and replaces that exact footer to expose the pure report
  in a browser; it deliberately fails if the emitter shape changes.
- Core has no DOM, clock, input, HTTP, or random effect runner. Playback buttons
  and scheduling therefore live in the viewer, while the entire state timeline
  remains Bend-owned.
- Direct normalization succeeds, but prints an extremely large structural
  representation because the result contains 36 full snapshots. Generated
  JavaScript is the practical execution path for the browser.
- A custom-ADT `main` works with the JavaScript backend but is outside the C
  driver's primitive result printer. This demo intentionally targets JS.

## Retest on Bend 2.0.40

- The bend2-core toolchain is gone; `build.sh` now uses `bend X.bend -o X.mjs`.
  That module ends in a single `export default { name: fn, ... }` object (no
  `import`s, no top-level `await`), so the "rewrite the emitted footer" bridge
  is replaced by rewriting that one `export default {` into a local binding
  and calling its `main()`. `build.sh` still refuses to guess if the shape
  changes. The old notes about the Core JS printer footer and the C driver's
  primitive-only printer no longer apply: `bend X.bend` now normalizes and
  prints a custom-ADT `main` directly (a few seconds).
- Not a bug, but worth knowing while porting: a destructuring let such as
  `(a, b) = f(x)` is a match, so (as the guide's "match inspects a parameter"
  rule says) it is only accepted on a parameter or pattern variable, never on
  a call or a local `let` binder. The port passes the pair to a helper def.
