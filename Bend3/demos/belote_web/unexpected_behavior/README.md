# Belote: Bend3 behavior notes

Retested with upstream Bend3 revision
`1ebc1acc739b565ddbf4dd243edf57ef10b65ebb` on 2026-08-17.

No compiler or runtime source was changed for Belote. The standalone program,
the hub-private generated module, and the unified BendJogos entry all pass the
current checker and native compiler. The pure deal/ranking probe returns `1`.

## Numeric Boolean patterns

Conditions represented as `U32` must be matched with numeric patterns such as
`case 0:` and `case _:`. Constructor-looking patterns such as `case False:`
are not interchangeable with `U32` zero. This surfaced while writing the legal
card and automatic-turn state machines.

## Generated module layout sensitivity

`generate_modules.mjs` prefixes every Belote declaration to prevent collisions
inside BendJogos's merged declaration book. The longer generated constructor
names exposed the parser's indentation/layout sensitivity in several dense
`match` rows: continuations that were visually adequate in the standalone
source could be interpreted differently after prefixing. The generator now
preserves deliberately wide continuation indentation, and both standalone and
generated forms are checked. Treat this as a source-layout hazard; no compiler
or runtime patch was made.

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
