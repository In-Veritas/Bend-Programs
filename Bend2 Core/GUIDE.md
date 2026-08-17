# Bend3 to Bend2 Core porting guide

This note describes the concrete differences observed while porting the
programs in this repository. Bend2 Core is a small strict-affine dependent
language; it is not Bend3 with a compatibility syntax.

## Affinity, demand, and duplication

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

## Termination and the `#[halts]` license

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

## Surface and data model

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

## IO and parallelism

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

## Backend model

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

## Verification strategy

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
