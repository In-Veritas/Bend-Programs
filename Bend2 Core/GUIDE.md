# Bend2 Core guide (ported to the latest Bend)

This folder holds Gabriel's Bend3 programs and the owner's observer demos as
first written for the experimental `bend2-core` affine dependent core. The
owner's last Core revision targeted `bend2-core` commit
`c5d69a14608b93896b5046e310d501903235d6c8` (`assert` + untyped `def`,
`main_value`, `Cop`-gated `+` binders, an IO loop). That compiler is gone; its
descendant is the latest Bend (bendlang/bend source, reporting `bend 2.0.40`),
and `programs/`, `demos/poker/` and `demos/belote/` are ported to it with all
of the owner's later content. This guide has three parts:

1. the current toolchain and what changed from Core;
2. how to write mathematical proofs here (the owner's proof workflow,
   translated to the latest Bend's `law` syntax); and
3. the historical bend2-core notes, kept as the record of why the ports look
   the way they do.

Read `bend guide` for the current language itself.

## Current toolchain

```sh
bend FILE.bend --check-only     # ALL PROOFS CHECK / SOME PROOFS FAIL
bend FILE.bend [args]           # check, then run main (IO compiled, a value normalized)
bend FILE.bend -o /tmp/out      # native binary (clang); -o x.c / -o x.js emit C / JS
bend FILE.bend -o x.mjs         # ES module of the non-IO defs (used by the demo builds)
```

`--verdict` (the recheck by the Lean-proved kernel) needs Lean, which is not
installed here; `--check-only` printing ALL PROOFS CHECK is the gate used.

What changed from Core to the latest Bend, as met in these ports:

| bend2-core | latest Bend |
|---|---|
| `type X:` | `type X is Data:` (copyable) or `is Type` (affine) |
| `assert f: forall x: A ... T` + `def f(x):` | `def f(x: A) -> T:`; a proposition is a `law f: for x: A ... T` proven by `def f(x):` |
| `U32.from_nat(42n)`, `U32.zero()`, `U32.one()` | U32 literals `42`, `0`, `1` (Base has no `U32.zero`/`U32.one` any more) |
| `U32.shln(n, x)`, `U32.shrn(n, x)` | `U32.shln(x, n)`, `U32.shrn(x, n)` |
| `U32.copy`/`Nat.copy`, structural copiers, `Copy(T, x)`, `Equal.copy`, `Cop` witnesses (`+T ~ w`) | `+x` quantities on Data values (reference-counted); no witness needed |
| `match f(x):`, `(a, b) = f(x)` | only parameters and pattern variables are matched or destructured; computed values go to a helper def |
| `#[halts]` whole-book license | gone; recursion must be structural (`@unsafe` is the per-def escape hatch, unused here) |
| `Sigma<A, x => B>` | dependent pair type `&x: A -> B`, values `(a, b)` |
| `main_value!()` (zero-argument call) | `main_value()`; `f!(..)` now means "run on the GPU" |
| `List<T>` | `List<T>` is `List<&1, T>`; a reusable list is `+List<T>` = `List<&2, T>`, measured with Base `List.length(&2, T, xs)` |
| no parallel primitive | parallel let `a b = f(x) g(y)` |
| IO loop with print/env/files/TCP/UDP, no argv/clock | adds `IO.args`, a clock, HTTP, windows, audio, ... |
| C driver prints only String/Bool/Nat/U32/Char | `bend FILE` normalizes and prints any value of a value-returning `main` |

The owner's Core convention is kept: a pure program names its self-check
`main_value()` and its `main() -> IO(Unit)` prints `True{}` / `False{}` (or
`Ready{}` for the demo reports, `-` for `nat_proofs`'s erased proof). The demo
builds export `main_value()` from the `.mjs` module, because an IO `main` is not
exported.

Common rewrites:

- A branch on a comparison becomes a helper that matches a `Bool` (or `Cmp`)
  parameter. When only the chosen branch may run (a recursive insert, a
  search), the helper takes thunks: `branch(U32.is_le(n, v), u => .., u => ..)`.
- The old Nat-fuel programs that needed `#[halts]` (or, in the owner's last
  revision, a `Cop`-gated reusable fuel) take a reusable `+fuel: Nat`; `merge`
  in `merge_sort` counts down a fuel equal to the total length.
- Defs are checked in file order and mutual recursion is refused: helpers go
  first, and a mutually recursive group (the Bend3 `gabs4` tokenizer) becomes
  one structural def threading a state value.
- An affine `Array` hands itself back beside every read, and that pair can
  only be destructured as a def parameter; the CHIP-8 emulator therefore keeps
  its memories in Data trees so the whole machine is a reusable `+Core`.
- A multi-scrutinee case cannot list two parenthesised tuple patterns
  (`case (a, b) (c, d):` is misparsed); write `Tuple{a, b} Tuple{c, d}`
  (filed as `bugs/multi-match-tuple-pattern-not-split`).
- Importing the compat list module under the alias `List` shadows Base's
  `List.*` names in that file; the poker/belote proofs therefore use Base's
  `List.length(&2, T, xs)` directly.

## Proofs in this folder

### What counts as a proof

A proposition is a type and a proof is a term of that type. `{left == right :
Nat}` states an equality; `{==}` proves it when both sides reduce to the same
term. A theorem is a `law` whose `for` binders are universally quantified:
Bend must check the proof for an arbitrary value, not for one value picked by
a test.

```python
law theorem:
  for xs: +List<Nat>
  {property_left(xs) == property_right(xs) : ResultType}

def theorem(xs):
  ...
```

This is fundamentally different from a closed check:

```python
law reference_certificate:
  {evaluate(reference_input()) == reference_output() : Output}

def reference_certificate():
  {==}
```

The closed equality is valuable evidence that one fixture has not regressed,
but it is a **certificate for that fixture**, not a mathematical proof of the
program for arbitrary inputs. Running every member of a small authored table
has the same limitation: it proves only that finite table. That is why the
poker and belote audits count their "78" and "119" closed certificates
separately from their general theorems.

Pattern matching is not automatically a substantial proof either. Constructor
analysis is valid when the law quantifies over an arbitrary value of an
algebraic type whose constructors exhaust the domain, but it is often just the
local step lemma; a useful end-to-end theorem still connects it to the real
algorithm and lifts it over arbitrary recursive data or histories. Count and
publish the summit theorem, not the splitter and its lifting as two results.
When a numeric bound is the real contract, prefer a proof-carrying arithmetic
witness such as `value + slack == limit` over listing enum constructors.

### State the property before proving it

Start with the semantic contract, not with whatever equality reduces easily.
A strong property mentions the actual public computation, arbitrary inputs (or
an explicit precondition), the invariant callers care about, and enough
structure that a weakened implementation would break the proof. Preserving
only the number of poker chips would allow one chip to silently change
identity or value, so `poker_proofs.bend` first proves preservation of the
full ordered identity/value payload and derives count and total value as
corollaries. Do not prove a shadow model and describe it as correctness of a
larger program, and give physical statements their physical hypotheses
(positive reflectance, positive energy, clear visibility, ...).

### A reliable proof architecture

1. Define the executable semantics (transition, evaluator, renderer, ...).
2. Define a semantic observation or relation that captures correctness.
3. Prove constructor-level or algebraic lemmas.
4. Prove one-step preservation for an arbitrary state and action.
5. Lift the step law over an arbitrary recursive input or finite history by
   structural induction.
6. Derive simpler observable corollaries with congruence.
7. Publish a named claim type and make an erased audit consume the theorem.
8. Keep closed reference scenarios in a separately counted certificate suite.

### Structural induction

A recursive proof def is structural induction. From `poker.bend`:

```python
law texas_cards_length_theorem:
  for indices: +List<Nat>
  { List.length(&2, U32, texas_cards_from_indices(indices)) == List.length(&2, Nat, indices) : Nat }

def texas_cards_length_theorem(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %texas_cards_length_theorem(tail) : {1n+List.length(&2, U32, texas_cards_from_indices(tail)) == 1n+_ : Nat}
      {==}
```

`tail` is arbitrary, the recursive call is the induction hypothesis, and the
law covers lists of every finite length. `%e : P` rewrites with `e`: `P` is
the goal with `_` marking the right-hand side of `e`. The recursive call must
be on a syntactic subterm; proofs do not license arbitrary recursion.

### Equality reasoning

Base provides `{==}`, `Equal.sym(A, a, b, ab) : {b == a : A}`,
`Equal.trans(A, a, b, c, ab, bc) : {a == c : A}` and
`Equal.cong(A, B, f, a, b, ab) : {f(a) == f(b) : B}`. Congruence is how a
strong invariant yields corollaries without repeating an induction:

```python
law history_chip_count_conservation_theorem:
  for history: +List<LedgerAction>
  for +chips: +List<Chip>
  { chip_count(settle_history(history, chips)) == chip_count(chips) : Nat }

def history_chip_count_conservation_theorem(history, chips):
  Equal.cong(
    +List<ChipPayload>, Nat,
    payload => List.length(&2, ChipPayload, payload),
    chip_payload(settle_history(history, chips)),
    chip_payload(chips),
    history_payload_conservation_theorem(history, chips))
```

For a two-argument function, transport one input at a time and join the two
equalities with `Equal.trans`, or rewrite twice with `%` (as
`settle_action_congruence` does).

### Propositions beyond equality

An equality to `True{}` is useful when a Boolean predicate is the executable
specification. For richer contracts, define a proposition as a def returning
`Type`: `A & B` proves both, a dependent pair `&x: A -> B(x)` carries a
witness (poker's `RandomnessWitness`, `SeatReachabilityWitness`), `Unit` is a
trivially true branch and `Empty` an impossible one. `{a != b : T}` is
`{a == b : T} -> Empty`; refute a constructor clash by rewriting through a
motive that sends one side to `Unit` and the other to `Empty` (poker's
`AdaOnly` / `ada_not_rook`). A recursive relation over two lists can make
missing and extra rows uninhabitable, and constructors such as
`Positive{excess: Nat}` make invalid states unrepresentable.

### Reuse in proofs

Proofs erase, but the values a proof passes to other proofs are still checked
for affinity. In the latest Bend a Data value is simply shared with a `+`
binder: the history induction takes `for +chips: +List<Chip>` and uses
`chips` both in the induction hypothesis and in the step lemma. The owner's
Core proofs needed structural copiers, `Copy(T, x)` replicas, their exactness
lemmas and `Equal.copy` for this; they are gone from the ports, and every
theorem statement is unchanged. A `+` binder is part of the theorem's type,
so a claim type that a `+`-quantified law must inhabit spells it `@+chips: ..`.
Uses in types, equality endpoints, erased (`-`) arguments and fields, and
match motives do not spend a value.

### Claim types and erased audits

A named claim makes the public theorem boundary reviewable, and a focused
entry forces it to stay checked while returning a printable `Bool`:

```python
def PokerChipCountConservationClaim() -> Type:
  @history: +List<LedgerAction> -> @+chips: +List<Chip> -> {
    chip_count(settle_history(history, chips)) == chip_count(chips) : Nat
  }

def verified(-count: PokerChipCountConservationClaim()) -> Bool:
  True{}

def main_value() -> Bool:
  verified(history_chip_count_conservation_theorem)
```

A law is referenced as a value by its bare name. Larger packages group the
proofs in erased fields of an audit record (`PokerVerificationAudit`,
`BeloteVerificationAudit`) that the report returned by `main_value` carries:
building the report checks every proof, and the JS export drops the erased
fields, leaving only the audit's text and counts for the page.

### Connecting a step theorem to a history theorem

A summit over a state machine composes the induction hypothesis with the
step law:

```text
observe(run(tail, step(action, state)))
  = observe(step(action, state))       by the induction hypothesis
  = observe(state)                     by step_preserves
```

With `+` binders that is one `Equal.trans` (see
`history_payload_conservation_theorem` in `demos/poker/poker_proofs.bend` and
its belote counterpart); the old Core terms were longer only because they
built and transported explicit replicas.

### Proving counts is not proving coverage

Cardinality alone is weak: `objects × lights` queries can have the right
length while duplicating one pair and omitting another. Prove the richer
structural relation (identity preservation, positional alignment, topology)
first and derive the count as a corollary.

### Proof review checklist

- Is the law universally quantified over the intended input or history?
- Does its statement mention the actual implementation function?
- Are all preconditions explicit in the type?
- Does it rule out duplication, omission and reordering where they matter?
- Does recursive coverage come from structural induction, not enumeration?
- Are closed scenarios named and counted as certificates?
- Is every proof consumed by an erased audit or focused test entry?
- Does a deliberately broken implementation make `--check-only` fail? (The
  poker/belote ports were mutation-tested this way.)
- Are failures attributed to Bend only after minimizing a genuine defect?

### Common proof mistakes

- **Finite enumeration described as universality.** Keep it as a certificate.
- **A theorem about metadata rather than live structure.**
- **A property that is true because it ignores the result.**
- **A Boolean with no relational alignment.**
- **Unstated domain assumptions** (overflow, nonzero divisors, visibility).
- **Trying to bypass structural termination**: restructure around the real
  subterm or add decreasing fuel; `@unsafe` makes the check fail.
- **Calling a language restriction a bug**: declaration order and
  match-only-on-parameters are rules, not defects.

### Where to study complete proofs

- `demos/poker/poker_proofs.bend`: arbitrary-history payload conservation and
  count/value corollaries (latest Bend);
- `demos/belote/belote_proofs.bend`: the corresponding card identity/point
  conservation tower (latest Bend);
- `programs/nat_proofs.bend`: small inductive laws over a unary Nat;
- `demos/bend_a_beet/*_proofs.bend` and `demos/Bend Engine/*_verification.bend`:
  the owner's larger Core proofs (scene coverage, physics histories, ragdoll
  topology, AI legality); see those packages' READMEs for their port status.

Read each proof from its claim type backward: first decide whether the summit
states the property you care about, then inspect the helper tower.

# Historical notes: bend2-core

The sections below describe the bend2-core revision the programs were first
ported to (`26cddb7`, 2026-08-17). The owner's later revision `c5d69a1`
changed some of it: `+` binders became legal when backed by a `Cop`
(`Copiable`) witness (`+Nat ~ Nat.copy`, or the structural `+T` sugar),
`#[halts]` was removed in favour of structural fuel, `main` became `IO<T>`
with the self-check in `main_value`, and the IO loop gained print, environment,
files, TCP and UDP on all backends (still no argv or clock).

## Affinity, demand, and duplication (bend2-core)

Bend3 can represent a shared value with `+T` and can pass that value repeatedly.
Bend2 Core permits every **live** binder at most once; it is affine, not linear,
so zero uses are also valid. Sequential uses add and a second live use is
rejected. Uses in mutually exclusive match arms are joined, which means the
same binder may appear once in every branch.

Reuse is a theorem and a runtime operation specific to the datatype:

```bend
((x1, exact1), (x2, exact2)) = U32.copy(x)
```

`U32.copy`, `Nat.copy`, `Bool.copy`, and `Word.copy` are supplied by `Base`.
User datatypes need their own structural copier. The Bend3 binary-search demo
shares one tree among four lookups; its Core port recursively rebuilds four
trees with `Tree.copy`. The transtyping port avoids generic copying by fusing
`getval` with conversion and copies only the concrete `U32` value at ancestors.

Copy proofs are erased, but the data copies are real. A certified copy of a
smaller recursive argument is not accepted as syntactically decreasing. This
is why `integer_sqrt.bend` and `tournament.bend` need `#[halts]`, even though
their Nat fuel decreases. `merge_sort.bend` also needs the license because one
of its two list arguments is rebuilt while the other shrinks. Reordering the
structural subject to the first parameter was sufficient for insertion and
tree insertion.

Demand is structural. Matching live data consumes the scrutinee, and live
constructor fields inherit that demand unless a field is explicitly erased
with `-`. Types, erased arguments and fields, equality carriers/endpoints, and
match motives are dead positions: their use does not spend a live value. Dead
terms can even diverge or inhabit `Empty`, but there is no legal promotion from
dead evidence into runtime data.

Closed top-level definitions are reusable. The restriction applies to live
local binders, not to referencing a closed function many times. Source `+T`
does not exist in Core; `+` is rejected at parse time, while the internal
`Many` quantity only appears as an overuse/formation failure.

## Termination and the `#[halts]` license (bend2-core)

Without a license, a direct recursive call must have the bare top-level
reference as its application head. Core compares live arguments
lexicographically and requires the first differing live column to be a
syntactic strict subterm. Erased columns are skipped. A proof that a copied
value equals a predecessor does not restore syntactic descent.

Normal book validation is declaration-ordered, so live forward references and
mutual recursion are unavailable. `#[halts]` is much broader than a local
termination annotation:

- it is recognized only when it is the first line of a parsed file;
- the flag is ORed across imports, so one licensed import licenses the merged
  book;
- it enables whole-book scope, including forward and mutual references;
- it disables the decreasing-self-call check; and
- it permits live unfilled assertions and self references as values.

Treat it as an unsafe whole-book escape hatch. The CHIP-8 emulator avoids it;
for example, its 4,096-cell initializer builds one decreasing subtree and then
uses a structural array copier instead of recursively calling `fill` on two
proof-copies of the predecessor.

## Surface and data model (bend2-core)

| Bend3 | Bend2 Core |
|---|---|
| `type List<T>` with `Cons` from Bend3 Base | `List<T>` with `Con` from Core Base |
| numeric infix operators | named functions such as `U32.add`, `U32.is_le` |
| U32 literals such as `42` | `U32.from_nat(42n)` |
| booleans commonly represented as `0`/nonzero U32 | `False{}` / `True{}` |
| `{a = b : T}` and `{=}` | `{a == b : T}` and `{==}` |
| shared `+T` values and parallel paired lets | affine values and sequential evaluation |
| direct and mutual definitions used by the demos | declaration-order scope unless the whole book is licensed |
| broad Base library: F32, String utilities, JSON, HTTP, TCP, effects | small Base: unary Nat, U32/Word, String shape, List, Array, equality |

Core imports are explicit (`import Base`). Functions use `def`, types use
`type`, constructor fields are affine, and multi-scrutinee matches place the
scrutinees side by side (`match xs ys:`).

File imports use `import path as Namespace`. One real file may have only one
namespace in a book, and import cycles are rejected. Base is not implicit.
Semicolon-free simple lets are term-level; a later destructuring local or
body-level `match` may require reordering the destructuring first or factoring
the computation into a helper.

## IO and parallelism (bend2-core)

`src/base.bend` declares an `IO.OP` effect tree and fiber/channel handle types,
but it supplies no `IO.print`, filesystem, clock, TCP, HTTP, JSON, or window
operations, and the JS/C drivers do not run the Bend3 IO scheduler. Consequently
the two authored IO programs and every interactive demo lack a runnable direct
port. Bend3 C-bodied effects (`import ./effs/name.c`) also have no Core
equivalent.

Bend3's paired let can fork independent work. Core has no implemented parallel
source primitive, so the tournament preserves its result but evaluates child
brackets sequentially.

The compiler does not turn an `IO.OP` tree into effects. JavaScript may print
the data representation of such a tree; the C entry driver only accepts
`String`, `Bool`, `Nat`, `U32`, or `Char`. This is why the CHIP-8 port embeds a
hex ROM string in an imported module and exposes key/framebuffer state as pure
data. That bridge is explicitly temporary until Core has real host input.

## Backend model (bend2-core)

Compilation erases `None` binders, erased constructor fields, proof arguments,
motives, and equality witnesses (`Rfl` has no useful runtime payload). The JS
backend maps canonical Base values to host values: Nat to `BigInt`, Bool to a
boolean, U32 to an unsigned number, Char/String to JavaScript text, and Array
to a JavaScript array.

The C backend uses tagged `Term` words and task/trampoline machinery for deep
recursion, closures, and mutual cycles. It has stricter lowering walls around
computed U32 wrappers and partial definition application. Both backends
recognize canonical Base operations by name; the Bend definitions are the
specification while the backend intrinsic is the machine implementation. This
explains why structural U32-heavy programs can normalize very slowly yet run
immediately after compilation. The C runtime banner currently says “Bend4
Runtime”; that is stale naming in this Bend2 Core checkout, not a different
target.

## Verification strategy (bend2-core)

Every computational port uses a `Bool` self-check rather than relying on the
printer to display nested `U32`/`Word` encodings. Each was checked with the
normalizer, compiled to JavaScript and C, and run through the available backend.
All eleven original computational ports return `True{}` in both generated
backends. The new CHIP-8 emulator also returns `True{}` in the normalizer,
generated JavaScript, and a native C executable.

`nat_proofs.bend` deliberately keeps its proposition as `main`: it normalizes
to `{==}`. JavaScript emission succeeds and prints `-` for the erased proof, but
the C emitter rejects the answer type because its driver accepts only String,
Bool, Nat, U32, or Char. This is a current backend capability mismatch, not a
failed proof.

The normalizer/backend boundary is also visible in `tournament.bend`. Direct
normalization unfolds Core Base's structural U32 multiplication, shifts, copies,
and the complete bracket; it did not finish after 18 minutes. Both generated
backends return `True{}` immediately because they lower those Base names to
native operations. Use `--to` for that file.
