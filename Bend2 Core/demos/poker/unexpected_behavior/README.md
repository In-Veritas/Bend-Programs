# Unexpected behavior and limitations

- Bend2 Core's JavaScript emitter always appends an immediate `main` printer.
  `build.mjs` verifies and replaces that exact footer to expose the pure result
  to a browser. It fails loudly if the compiler changes the footer.
- Core has no browser/clock/input effect runner, so playback controls belong to
  the viewer. The complete state sequence remains Bend-owned.
- A custom-ADT `main` is supported by generated JavaScript but is outside the C
  driver's primitive result printer. This demo deliberately targets the JS
  backend requested for the comparison hub.

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
