# Poker: Bend3 behavior notes

- The Bend parser requires explicit parentheses for mixed/chained binary
  expressions. The evaluator uses named intermediate values instead of relying
  on precedence.
- Polymorphic list helpers require their type argument at calls where inference
  cannot recover it, for example `List.concat(U32, hole, board)`.
- A constructor assigned to a local and immediately passed to another function
  sometimes needs an explicit `: Game` annotation.
- Hub-private namespacing lengthens declaration and call names. The generated
  form therefore needs deliberately wide continuation indentation for an
  inline `match` in `game_new`; otherwise its case rows are no longer deeper
  than the rewritten match expression. Standalone and generated forms are both
  checked. No compiler/runtime change was made.

## Retest on Bend 2.0.40 (2026-11-23)

The source was rewritten for Bend 2.0.40 and rechecked with the current
bendlang/bend `bend2/main.ts` (6b806192): ALL PROOFS CHECK, native build, and
the HTTP regression tests pass on both. The notes above no longer apply as
such: Bend 2.0.40 has no generated hub modules (a hub imports this file under
an alias, so no name prefixing and no layout hazard), comparisons answer
`Bool` (matched as `True{}`/`False{}`, U32 literal patterns still work for
numbers), and operators always take an explicit `( .. : U32)` type, so mixed
expressions no longer need extra parentheses. New observations, none of them
a Bend bug: `match` only scrutinizes parameters/pattern variables and may not
follow a `let` (helpers take the computed value as a parameter); a let-bound
constructor needs a type (`+g : Game = Game{..}`); a `Nat` matched as `1n+n`
in a non-`+` parameter cannot be rebuilt and reused (mark the parameter `+`).
Normalizing a value `main` that plays a whole AI deal in the checker is very
slow, so the probe's `main` is IO and runs compiled.
