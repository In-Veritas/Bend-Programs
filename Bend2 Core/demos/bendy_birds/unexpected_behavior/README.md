# Erased proof binder escapes a compiled continuation

First verified with upstream Bend revision
`c5b919ab161f42815503164d7864ae3c82c72147` and reproduced at
`c5d69a14608b93896b5046e310d501903235d6c8`.

`erased_proof_continuation.bend` is a minimized backend failure. The checker
accepts a recursive `Claim` whose equality proof is stored in an erased field.
The constructor combines the proofs returned by two sequential calls. This is
valid Core: the same proof tower works when factored into a named theorem whose
result remains erased.

Run from the Bend repository:

```sh
bun bend2/comp.ts \
  "../Bend-Programs/Bend2 Core/demos/bendy_birds/unexpected_behavior/erased_proof_continuation.bend"

bun bend2/comp.ts \
  "../Bend-Programs/Bend2 Core/demos/bendy_birds/unexpected_behavior/erased_proof_continuation.bend" \
  --to /tmp/erased-proof-continuation.js
bun /tmp/erased-proof-continuation.js

bun bend2/comp.ts \
  "../Bend-Programs/Bend2 Core/demos/bendy_birds/unexpected_behavior/erased_proof_continuation.bend" \
  --to /tmp/erased-proof-continuation.c
```

Expected: the interpreter and generated JavaScript print `True{}`, and C
emission succeeds.

Actual:

- the interpreter and generated JavaScript fail with
  `ReferenceError: tail_exact is not defined`;
- the generated JavaScript continuation reads bare `tail_exact` even though
  that erased binder was correctly omitted from its runtime captures; and
- C emission fails with
  `tocl: a use of an unbound binder: ~ (report this case)`.

The application workaround is to move the equality composition into a named
proof theorem and use that theorem in the erased `Claim` field. This preserves
the same universally quantified property and lets the checker, JavaScript
backend, and application run agree. The minimized file deliberately retains
the failing inline form as regression evidence.

## Retest on the latest Bend (bendlang/bend source, `bend 2.0.40`)

The original MRE above uses the old `assert` syntax and no longer parses.
`erased_proof_continuation_latest.bend` ports it: the same recursive `Claim`
with an erased equality field built from the proofs of two sequential calls
(`box_claim(head)` and `list_claim(tail)`). Because the latest Bend matches only
parameters, the two results are opened by a helper `list_claim.join` instead
of nested `match f(x):` continuations. It does **not** reproduce:

```sh
bend erased_proof_continuation_latest.bend --check-only   # ALL PROOFS CHECK
bend erased_proof_continuation_latest.bend                # True{}
bend erased_proof_continuation_latest.bend -o /tmp/e.c    # C emitted
bend erased_proof_continuation_latest.bend -o /tmp/e && /tmp/e          # True{}
bend erased_proof_continuation_latest.bend -o /tmp/e.js && bun /tmp/e.js  # True{}
```

The same holds with the original's GPU-style calls (`box_claim!(head)`,
`check!()`): check, interpreter, native and JS all print `True{}`. No
`ReferenceError` and no `tocl: a use of an unbound binder` occur, so no bug
report was filed. (Retest only; the bendy_birds port itself is separate.)
