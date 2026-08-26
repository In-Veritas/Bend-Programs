# Bend2 Core guide

This guide describes the Bend2 Core language used by this repository, the
important differences from Bend3, and a practical method for writing
mathematical proofs that Core checks and erases before execution. The examples
target `bend2-core` commit `c5d69a14608b93896b5046e310d501903235d6c8`.

Bend2 Core is a small, pure, strict-affine dependently typed language. It is
not Bend3 with compatibility syntax. Its main characteristics are:

- algebraic data types, pattern matching, first-class functions, and
  structurally checked recursion;
- dependent function types and equality types, so propositions and proofs can
  live in the same language as programs;
- strict affinity: a live local value may be consumed at most once, while
  erased types and proofs do not consume runtime data; reusable binders require
  a checked `Copiable` witness through the new `Cop` type form;
- an `assert` declaration for every definition's full type, followed by a
  separate `def` fill with bare binders;
- declaration-ordered books, with explicit imports merged into one checked
  declaration book;
- proof erasure before JavaScript or C execution;
- a deliberately small Base library plus an implemented IO loop shared by the
  interpreter, JavaScript, and C backends.

The best use of Core today is a pure computational kernel with its correctness
contract expressed as checked types. A browser, service, or native shell may
display the resulting data, but that host is not part of the Core proof unless
its semantics are represented in Core too.

## Checking a program

Run the compiler from a matching `bend2-core` checkout. Do not assume a source
still checks after a language revision:

```sh
bun bend2/comp.ts ../Bend-Programs/Bend2\ Core/programs/insertion_sort.bend
bun bend2/comp.ts ../Bend-Programs/Bend2\ Core/programs/insertion_sort.bend \
  --to /tmp/insertion_sort.js
bun /tmp/insertion_sort.js

bun bend2/comp.ts ../Bend-Programs/Bend2\ Core/programs/insertion_sort.bend \
  --to /tmp/insertion_sort.c
clang -O2 /tmp/insertion_sort.c -o /tmp/insertion_sort
/tmp/insertion_sort
```

Direct normalization is useful for small terms and proof exploration.
Generated JavaScript and C are usually better evidence for larger
computations, especially when the backends intrinsify structural Base
operations.

## Affinity, demand, and duplication

Bend2 Core permits every ordinary **live** binder at most once; it is affine,
not linear, so zero uses are also valid. Sequential uses add and a second live
use is rejected. Uses in mutually exclusive match arms are joined, which means
the same binder may appear once in every branch. A reusable `+` binder is legal
only when its type carries a valid `Copiable` witness, written explicitly as
`+ T ~ witness` or obtained through the structural `+T` sugar.

Reuse is a theorem and a runtime operation specific to the datatype:

```bend
((x1, exact1), (x2, exact2)) = U32.copy(x)
```

`U32.copy`, `Nat.copy`, `Bool.copy`, and `Word.copy` are supplied by `Base`.
User datatypes need their own structural copier. The Bend3 binary-search demo
shares one tree among four lookups; its Core port recursively rebuilds four
trees with `Tree.copy`. The transtyping port avoids generic copying by fusing
`getval` with conversion and copies only the concrete `U32` value at ancestors.

The new `Cop` form makes that evidence part of a reusable binder's type:

```bend
assert Nat.double:
  forall +x: +Nat ~ Nat.copy
  Nat

def Nat.double(x):
  Nat.add(x, x)
```

The shorter `+Nat` expands to the same datatype-specific witness. For a
generic `T`, pass a `T.copy: Copiable(T)` witness explicitly. The checker locks
the definitions of `Sigma`, `Copy`, and `Copiable`, so a forged witness cannot
turn an arbitrary affine value into unrestricted sharing.

Copy proofs are erased, but the data copies are real. A certified copy of a
smaller recursive argument is not accepted as syntactically decreasing. Use a
proof-gated reusable structural binder when the actual predecessor must appear
more than once. If different data arguments shrink in turns, carry a separate
structural fuel value, as `merge_sort.bend` does with combined list length.
Reordering the structural subject to the first parameter remains sufficient
for insertion and tree insertion.

Demand is structural. Matching live data consumes the scrutinee, and live
constructor fields inherit that demand unless a field is explicitly erased
with `-`. Types, erased arguments and fields, equality carriers/endpoints, and
match motives are dead positions: their use does not spend a live value. Dead
terms can even diverge or inhabit `Empty`, but there is no legal promotion from
dead evidence into runtime data.

Closed top-level definitions are reusable. The restriction applies to live
local binders, not to referencing a closed function many times. A `+` binder
without valid copy evidence is rejected even though its erased witness does not
survive execution.

## Termination

Every direct recursive call must have the bare top-level reference as its
application head. Core compares live arguments
lexicographically and requires the first differing live column to be a
syntactic strict subterm. Erased columns are skipped. A proof that a copied
value equals a predecessor does not restore syntactic descent.

Normal book validation is declaration-ordered, so live forward references and
mutual recursion are unavailable. The old `#[halts]` whole-book escape hatch
has been removed; `#` now starts an ordinary comment and all termination,
scope, assertion-liveness, escape, and `Copiable` walls always apply. The
CHIP-8 emulator's 4,096-cell initializer therefore builds one decreasing
subtree and then uses a structural array copier instead of recursively calling
`fill` on two proof-copies of the predecessor.

## Bend3 and Bend2 Core compared

| Bend3 | Bend2 Core |
|---|---|
| general-purpose language and evolving application runtime | small experimental dependent core used here for verified kernels and a compact standard IO boundary |
| unrestricted ordinary values plus explicit `+T` sharing | ordinary live locals are affine; reusable `+T` binders require `Copiable(T)` evidence |
| broad recursion patterns used by the demos | structural descent is always checked syntactically |
| direct and mutual definitions commonly used | declaration-order scope; live forward and mutual references are unavailable |
| broad application libraries including HTTP, JSON, graphics and clocks | IO loop with print/stderr/environment, files, TCP, UDP, sockets and listeners; no HTTP, JSON, window, clock, argv or browser API |
| broad Base and application libraries | compact Base: Nat, U32/Word, F32, String, List, Array, equality, copying and the standard effect kit |
| paired lets can express independent parallel work | `Par`/`Both` fork-let sugar lowers to backend forks; CLI flags control CPU/GPU execution |
| `type List<T>` with `Cons` from Bend3 Base | `List<T>` with `Con` from Core Base |
| typed definitions in the current Bend3 surface | every function uses a separate `assert` type followed by a bare-binder `def` fill |
| numeric infix operators | U32 infix operators plus named functions such as `U32.add`; F32 operators have a trailing dot |
| U32 literals such as `42` | contextual U32 literals such as `42`; unary Nat literals retain the `n` suffix |
| booleans commonly represented as `0`/nonzero U32 | `False{}` / `True{}` |
| `{a = b : T}` and `{=}` | `{a == b : T}` and `{==}` |
| shared `+T` values | affine ordinary values and proof-gated `Cop` sharing |

Core imports are explicit (`import Base`). Every function or type-level
definition first declares its whole type with `assert`, then supplies a `def`
with bare binder names. Types use `type`, constructor fields are affine, and
multi-scrutinee matches place the scrutinees side by side (`match xs ys:`):

```bend
assert append_one:
  forall xs: List<U32>
  List<U32>

def append_one(xs):
  Con{1, xs}
```

File imports use `import path as Namespace`. One real file may have only one
namespace in a book, and import cycles are rejected. Base is not implicit.
At `c5d69a1` the import path token itself cannot contain whitespace and has no
quoted-path form. A package stored under a human-facing directory with spaces
can expose a tracked no-space symlink for Core imports; Bend-a-Beet's `engine`
link to `../Bend Engine` is the repository example. Import the real file under
only one namespace even when a symlink is involved, because Core resolves real
paths when detecting duplicate imports and cycles.
Semicolon-free simple lets are term-level; a later destructuring local or
body-level `match` may require reordering the destructuring first or factoring
the computation into a helper.

## IO and parallelism

Core now implements a continuation-based `IO<T>` event loop consistently in
the interpreter, generated JavaScript, and generated C. `IO.print` and
`IO.write` provide line and raw output; the standard foreign-effect kit also
provides stderr, environment lookup, file open/read/write/close, TCP, UDP, and
socket/listener close operations. Fallible effects return `Result`, and
consumed handles are threaded back outside that result so failure cannot lose
the resource.

An executable compiled `main` must have type `IO<T>`. The pure ports therefore
keep their old result in `main_value` and use a small IO wrapper to force and
print it. `gabs1` is now a direct runnable port. Core still has no command-line
argument API, clock, HTTP/JSON stack, window or browser API, so `gabs4` and the
interactive host portions of the demos remain outside the current boundary.
The CHIP-8 port continues to embed a hexadecimal ROM and model keys as explicit
data because neither argv nor interactive keyboard input is exposed.

Fork lets (`&x: A = left &y: B = right; body`) construct and immediately
eliminate `Par<A,B>`/`Both`; eligible compiled calls become runtime forks.
`--parallel on|off`, `--threads N`, and `--gpu on|off` select execution policy.
The existing tournament port remains intentionally sequential, so its result
does not depend on scheduler configuration.

## Backend model

Compilation erases `None` binders, erased constructor fields, proof arguments,
motives, and equality witnesses (`Rfl` has no useful runtime payload). The JS
backend maps canonical Base values to host values: Nat to `BigInt`, Bool to a
boolean, U32 to an unsigned number, Char/String to JavaScript text, and Array
to a JavaScript array.

The C backend uses tagged machine words plus task/trampoline machinery for deep
recursion, closures, and parallel joins. Both generated backends recognize
canonical Base operations by name; the Bend definitions are the specification
while backend intrinsics provide the machine implementation. This explains why
structural U32-heavy programs can normalize very slowly yet run immediately
after compilation. Both backends now enter the same IO protocol instead of
using an answer-type-specific printer.

## Verification strategy

Every computational port keeps a `Bool` self-check rather than relying on a
printer to display nested `U32`/`Word` encodings. Its `IO<Unit>` main prints the
result. All computational programs, including CHIP-8, return `True{}` through
generated JavaScript and native C. `nat_proofs.bend` instead passes its erased
equality witness to an IO wrapper and prints `-`; both generated backends now
accept that entry because `main` itself has the required IO type.

The normalizer/backend boundary is also visible in `tournament.bend`. Direct
normalization unfolds Core Base's structural U32 multiplication, shifts, copies,
and the complete bracket; it did not finish after 18 minutes. Both generated
backends return `True{}` immediately because they lower those Base names to
native operations. Use `--to` for that file.

## Proofs in Bend2 Core

### What counts as a proof

In Core, a proposition is a type and a proof is a term of that type. For
example, this type states that `left` and `right` are equal values of type
`Nat`:

```bend
{left == right : Nat}
```

When both sides reduce to the same term, reflexivity constructs the proof:

```bend
{==}
```

A theorem is normally a function whose result is a proposition. Its arguments
are universally quantified: Core must check the body for an arbitrary value,
not just for one value selected by a test:

```bend
assert theorem:
  forall xs: List<Nat>
  property_left(xs) == property_right(xs)
  : ResultType

def theorem(xs):
  ...
```

This is fundamentally different from a closed check:

```bend
assert reference_certificate:
  evaluate(reference_input()) == reference_output()
  : Output

def reference_certificate():
  {==}
```

The closed equality is valuable evidence that one fixture has not regressed,
but it is a **certificate for that fixture**, not a mathematical proof of the
program for arbitrary inputs. Running every member of a small authored table
has the same limitation. It proves only that finite table.

Pattern matching is not automatically a substantial proof either. Constructor
analysis is mathematically valid when the theorem quantifies over an arbitrary
value of an algebraic type and the constructors really exhaust that entire
domain. It is often just the local step lemma. A useful end-to-end theorem must
still connect that lemma to the real algorithm and lift it over arbitrary
recursive data, state transitions, or histories.

Do not inflate the audit by counting that finite constructor splitter and its
arbitrary-history lifting as two comparable results. Count and publish the
summit theorem. The local splitter is proof machinery; the induction is what
turns it into a statement about every finite execution. When a numeric bound is
the real contract, prefer a proof-carrying arithmetic witness such as
`value + slack == limit` over merely listing the currently available enum
constructors.

### State the property before proving it

Start with the semantic contract, not with whatever equality happens to reduce
easily. A strong property usually mentions:

- the actual public computation being verified;
- arbitrary inputs or a clearly stated precondition;
- the observable invariant or relation that matters to callers; and
- enough structure that weakening the implementation would break the proof.

For example, preserving only the number of poker chips would allow one chip to
silently change identity or value. The Poker proof therefore first proves
preservation of the full ordered identity/value payload. Count and total value
are then corollaries. Likewise, the Bend Engine physics proof preserves an
`ArticulationShape` derived from the live ragdoll tree, rather than trusting a
separate metadata count.

Do not prove a shadow model and describe that as correctness of a larger
program. A theorem about a simplified transition kernel establishes only that
kernel unless another checked theorem connects it to the application entry.
Make that boundary explicit in names and documentation.

Physical statements need physical hypotheses. “Every surface reflects
positive light” is false for a zero-reflectance material, a back-facing
surface, or an occluded light. “Every object has a visible shadow” is false in
an empty scene. Encode the honest contract instead: positive reflectance,
positive incident energy, and clear visibility imply a positive reflection;
every object/light pair receives an occlusion query whose result may be clear
or occluded.

### A reliable proof architecture

For a nontrivial program, build the proof as a tower:

1. Define the executable semantics: the transition, evaluator, planner,
   renderer, or collection transformation.
2. Define a semantic observation or relation that captures correctness.
3. Prove constructor-level or algebraic lemmas.
4. Prove one-step preservation for an arbitrary state and arbitrary action.
5. Lift the step theorem over an arbitrary recursive input or finite history by
   structural induction.
6. Derive simpler observable corollaries with congruence.
7. Publish a named claim type and make an erased audit consume the polymorphic
   theorem function.
8. Keep closed reference scenarios in a separately counted certificate suite.

This is the same broad architecture used by the larger Bend3 proof demos, but
the Core version must explicitly respect affinity, structural termination, and
declaration order.

### Structural induction

Recursive theorem functions are Core's direct expression of structural
induction. This compiled Belote theorem proves length preservation for every
finite list of indices:

```bend
assert play_steps_from_indices_length_theorem_func:
  forall indices: List<Nat>
  List.length(Step, play_steps_from_indices_func(indices))
  == List.length(Nat, indices)
  : Nat

def play_steps_from_indices_length_theorem_func(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %play_steps_from_indices_length_theorem_func(tail) : {
        1n+List.length(Step, play_steps_from_indices_func(tail)) == 1n+_
        : Nat
      }
      {==}
```

The two branches are not a finite test suite. `tail` is arbitrary, the
recursive call is the induction hypothesis, and the theorem covers lists of
every finite length. The `%... : ...` annotation asks Core to view the
induction hypothesis at the refined successor goal before reflexivity closes
the branch.

Induction over histories has the same shape:

```bend
assert run:
  forall history: List<Action>
  forall state: State
  State

def run(history, state):
  match history:
    case Nil{}:
      state
    case Con{action, tail}:
      run(tail, step(action, state))

assert history_invariant_theorem:
  forall history: List<Action>
  forall state: State
  observe(run(history, state)) == observe(state)
  : Observation

def history_invariant_theorem(history, state):
  match history:
    case Nil{}:
      {==}
    case Con{action, tail}:
      # Combine the induction hypothesis for tail with the theorem for step.
      ...
```

The recursive call must be on a syntactic subterm such as `tail`. Proofs do
not justify arbitrary runtime recursion to the termination checker, and there
is no escape hatch from this check.

### Equality reasoning

Core Base provides four essential equality operations.

Reflexivity closes a definitionally equal goal:

```bend
{==}
```

Symmetry reverses an equality:

```bend
Equal.sym(A, a, b, proof_ab)
# result: {b == a : A}
```

Transitivity chains two steps:

```bend
Equal.trans(A, a, b, c, proof_ab, proof_bc)
# result: {a == c : A}
```

Congruence transports equality through a function:

```bend
Equal.cong(
  A,
  B,
  value => observe(value),
  left,
  right,
  proof_left_right
)
# result: {observe(left) == observe(right) : B}
```

Congruence is how a strong invariant yields smaller corollaries. If a history
preserves the entire chip payload, applying `List.length` proves chip-count
conservation without repeating the history induction:

```bend
assert history_chip_count_conservation_theorem:
  forall history: List<LedgerAction>
  forall chips: List<Chip>
  chip_count(settle_history(history, chips)) == chip_count(chips)
  : Nat

def history_chip_count_conservation_theorem(history, chips):
  Equal.cong(
    List<ChipPayload>,
    Nat,
    payload => List.length(ChipPayload, payload),
    chip_payload(settle_history(history, chips)),
    chip_payload(chips),
    history_payload_conservation_theorem(history, chips)
  )
```

For a two-argument function, transport one input at a time and join the two
equalities with `Equal.trans`. The Bend Engine AI determinism proof uses this
shape to replace a goal and an observation independently.

### Propositions beyond equality

An equality to `True{}` is useful when a Boolean predicate is the executable
specification:

```bend
{plan_valid_for_squad_func(plan, squad) == True{} : Bool}
```

For richer contracts, define a proposition as a dependent type. Product
notation `A & B` proves both properties. Base's `Sigma<A, B>` carries a witness
whose second component may depend on the first. `Unit` represents a trivially
satisfied branch, and `Empty` represents impossibility.

A recursive relation can make exact alignment part of the type:

```bend
assert SceneContract:
  forall obligations: List<SurfaceObligations>
  forall results: List<SurfaceResponses>
  Type

def SceneContract(obligations, results):
  match obligations results:
    case Nil{} Nil{}:
      Unit
    case Nil{} Con{result, result_tail}:
      Empty
    case Con{surface, surface_tail} Nil{}:
      Empty
    case Con{surface, surface_tail} Con{result, result_tail}:
      {surface_contract_valid(surface, result) == True{} : Bool}
      & SceneContract(surface_tail, result_tail)
```

This says more than “all produced rows look valid”: missing and extra rows are
uninhabitable too. The theorem returns a nested pair of the head proof and the
induction hypothesis.

Constructor design can make invalid states unrepresentable. Instead of a raw
action followed by a Boolean legality check, Bend Engine AI returns a
`Decision` constructor containing exactly the observation evidence required by
that action. A proof over arbitrary `Decision` values can then recover legality
by constructor analysis. This is constructive proof, not post-hoc testing.

Preconditions can also be represented constructively. For example:

```bend
type Positive:
  Positive{excess: Nat}
```

Every inhabitant denotes one plus some `excess`; zero has no constructor. A
reflection theorem accepting `Positive` reflectance and incident light cannot
accidentally be applied to zero.

### Affine proof engineering

Proofs erase, but the values mentioned by a proof may still be live inputs to
the computation. Core will reject a theorem body that consumes the same live
local twice. Do not treat affinity errors as invitations to weaken the claim.
Use a datatype-specific copier and retain its equality witnesses:

```bend
((left_value, left_exact), (right_value, right_exact)) = Nat.copy(value)
```

For user data, write a structural copier. A certified copy has the shape
`Copy(T, original)`, which is a pair of the replica and a proof that it equals
the original. When one equality witness is needed in two sequential places,
`Equal.copy` duplicates the erased proof:

```bend
((e0, e0_copy), (e1, e1_copy)) = Equal.copy(A, left, right, equality)
```

The data copies have real runtime cost if they survive erasure. Equality
witnesses do not. Prefer a proof design that observes one strong invariant and
derives corollaries, because it usually needs fewer live copies than several
independent inductions.

The following uses do not spend a live value:

- a type or equality endpoint;
- an erased argument or erased constructor field, written with `-`;
- a match motive; and
- a proof term that is erased before runtime.

The following do spend it:

- passing it to two sequential runtime calls;
- matching it and then using the original live value again; and
- constructing two runtime outputs from the same local without a copier.

Mutually exclusive branches use the join of their demands, so one use in each
match branch is normally legal.

### Claim types and erased audits

A named claim makes the public theorem boundary reviewable:

```bend
assert HistoryInvariantClaim:
  Type

def HistoryInvariantClaim():
  @history: List<Action> -> @state: State -> {
    observe(run(history, state)) == observe(state)
    : Observation
  }
```

The implementation theorem must have that full polymorphic type. A focused
entry can force the imported theorem to remain checked while returning a
backend-printable `Bool`:

```bend
assert verified:
  forall -proof: HistoryInvariantClaim()
  Bool

def verified(proof):
  True{}

assert main:
  IO(Unit)

def main():
  match verified(history_invariant_theorem):
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")
```

The leading `-` in the assertion makes the proof argument erased. JavaScript
and C execute only the IO wrapper, but compilation checks the entire theorem
body. Executable mains now must be `IO<T>`; keeping the proof in `main_value` or
an erased audit makes that runtime boundary explicit.

Large packages can group several erased theorem fields in an audit type. Keep
all referenced theorem definitions earlier in declaration order, or place the
audit in a later importing module. That is ordinary Core scoping, not a
compiler defect.

### Connecting a step theorem to a history theorem

For state machines, a robust summit theorem usually needs three ingredients:

1. `step_preserves`: one arbitrary action preserves the observation;
2. `step_congruence`: equal actions and states produce equal next states; and
3. `history_preserves`: induction over the arbitrary action list.

The history induction composes:

```text
observe(run(tail, step(action, state)))
  = observe(step(action, state))       by the induction hypothesis
  = observe(state)                     by step_preserves
```

In an affine implementation, the actual Core term may be longer because it
constructs explicit replicas, transports them with `step_congruence`, and
chains the equalities with `Equal.trans`. That length is not pointless bulk:
each term records a real logical or resource-use step. The Poker and Belote
payload proofs in this repository are complete worked examples.

### Proving counts is not proving coverage

Cardinality alone is weak. `objects × lights` queries could have the right
length while duplicating one pair and omitting another. A rendering proof
should therefore establish both:

- cardinality: exactly `object_count * light_count` results; and
- semantics: the result at each object/light ordinal names that exact object
  and light and satisfies the response contract.

The same principle applies elsewhere:

- a plan needs one decision per agent **and** positional agent alignment;
- a mesh needs the expected facet count **and** valid vertex/fur references;
- a ragdoll needs the same body count **and** the same recursive topology and
  joint kinds;
- a card game needs 32 cards **and** preservation of each card identity.

Prove the richer structural relation first. Derive the count theorem as a
corollary when possible.

### Proof review checklist

Before calling a Core result a mathematical proof, check all of the following:

- Is the theorem universally quantified over the intended input, state, tree,
  plan, or history?
- Does its statement mention the actual implementation function?
- Are all physical or logical preconditions explicit in the type?
- Does the property rule out duplication, omission, and reordering where those
  matter, rather than checking only a count?
- Does recursive coverage come from structural induction on an arbitrary
  value, not from enumerating an authored fixture?
- Are constructor cases used as local lemmas rather than presented alone as
  whole-program correctness?
- Are simpler results derived from a stronger invariant instead of proved by
  disconnected checks?
- Are closed scenarios named and counted as certificates?
- Is every proof consumed by an erased audit or focused test entry?
- Does every recursive call expose an actual syntactic subterm?
- Do generated JavaScript and C both compile and run with an `IO<T>` main?
- Are any failures attributed to Bend only after minimizing a genuine parser,
  checker, compiler, Base, runtime, or backend defect?

### Common proof mistakes

**Finite enumeration described as universality.** Checking all rows in one
embedded table proves that table only. Keep it as a certificate and add an
inductive theorem over the data generator or semantic transition.

**A theorem about metadata rather than live structure.** A stored `body_count`
can remain unchanged while the ragdoll tree loses a body. Derive the observed
shape from the tree being transformed.

**A property that is true because it ignores the result.** Ensure the
specification inspects the output and would fail for a plausible broken
implementation.

**A Boolean with no relational alignment.** “Every remaining result is valid”
does not show that every input received a result. Use a two-list relation or an
index-specific theorem.

**Unstated domain assumptions.** Fixed-point overflow, normalized vectors,
nonzero divisors, visibility, and positive energy are not automatic. Put the
assumption in a constructor, proof argument, or carefully documented boundary.

**Trying to bypass structural termination.** Equality evidence about a copied
predecessor does not make that copy syntactically smaller. Restructure the
recursion around the actual subterm or add a separate decreasing fuel value.

**Calling a language restriction a bug.** Declaration order and the grammar of
body-level `match` are constraints of this Core revision. Record only a
minimized behavior that contradicts the language/checker/backend contract, not
ordinary syntax mistakes or application bugs.

## Where to study complete proofs

The most substantial Core examples in this repository are:

- `demos/poker/poker_proofs.bend`: arbitrary-history payload conservation and
  count/value corollaries with explicit affine copying and equality transport;
- `demos/belote/belote_proofs.bend`: the corresponding card identity/point
  conservation tower;
- `demos/bend_a_beet/scene_proofs.bend`: dependent scene coverage with honest
  reflection and shadow hypotheses;
- `demos/bend_a_beet/physics_history_proofs.bend`: planted-anchor invariance and
  fracture absorption over arbitrary motion histories; and
- `demos/Bend Engine/*_verification.bend`: mesh/light/ray semantics, recursive
  ragdoll topology preservation, and deterministic legality-carrying AI over
  arbitrary plans and histories.

Read each proof from its claim type backward: first decide whether the summit
states the property you care about, then inspect the helper tower that inhabits
it. That review order makes vacuous or underspecified claims much easier to
spot than reading `{==}` branches in isolation.
