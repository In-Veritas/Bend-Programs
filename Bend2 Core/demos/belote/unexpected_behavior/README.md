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

## Owner's later Core note (c5b919a / c5d69a1), preserved

Upstream recorded that from Bend2 Core `c5b919a` compiled `main` had to be
`IO<T>`, so the kernel moved its report into `main_value`, both backends
printed `Ready{}`, and the browser builder replaced the IO footer with a call
to the pure root. The Core compiler also emitted only definitions reachable
from an executable root (documented whole-program elimination, not a defect).

## Retest on the latest Bend (port of the owner's verified version)

- Same shape on the latest Bend: `main_value() -> BeloteReport` is the pure
  report and `main() -> IO(Unit)` prints `Ready{}` (`bend belote.bend` and the
  native build both print it). `bend X.bend -o X.mjs` still exports every
  non-IO def, so `build.sh` evaluates `bend_exports.main_value()`; no
  reachability trick is needed.
- Erased constructor fields (`-deck_cards: ...` in `BeloteVerificationAudit`)
  are accepted in an `is Data` type and vanish from both the JS value and the
  native one; the JS audit object carries only its strings and counts.
- A quantity is part of a dependent function type: a law proven with
  `for +cards` has type `@+cards: ... -> ...`, which does not match a claim
  written `@cards: ...`. The named `Belote*Claim` types therefore say
  `@+cards`. Expected behaviour, noted because the mismatch message is easy
  to misread.
- `bend belote.bend --check-only` now takes about 40 s on this machine: the
  checker normalizes the 119 closed certificates (in particular the 36-snapshot
  `report_length_certificate` and the 32 legality certificates).
