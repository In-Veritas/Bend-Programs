# Ported programs

These started as strict-affine ports of Gabriel's Bend3 programs for the old
`bend2-core`, and are now ported to the latest Bend (bendlang/bend source,
`bend 2.0.40`). They keep the Core style: explicit Base calls (`U32.add`,
`U32.is_le`, ...) rather than much operator sugar, and `Bool` self-checks for
the pure programs. Every file checks with `ALL PROOFS CHECK`, and none uses
`#[halts]` (gone) or `@unsafe`.

Following the owner's later Core revision ("Update programs for current Bend2
Core"), each pure program names its self-check `main_value() -> Bool` and has
an executable `main() -> IO(Unit)` that prints `True{}` (or `False{}`) through
a small `main_show_bool`. So the interpreter, a native binary and the JS build
all report through the same IO path:

```sh
bend insertion_sort.bend               # check, then run main: True{}
bend insertion_sort.bend --check-only  # ALL PROOFS CHECK
bend insertion_sort.bend -o /tmp/isort && /tmp/isort   # native: True{}
bend insertion_sort.bend -o /tmp/isort.js && bun /tmp/isort.js
bend gabs4.bend fixtures/reference.txt fixtures/other.txt
```

| Bend3 source | prints | important adaptation |
|---|---|---|
| `appop` | `True{}` | Nat-pattern dispatch in a helper (matches take parameters only) |
| `binary_search` | `True{}` | one `+Tree` shared by four probes; `Tree.copy` no longer needed |
| `gabs1` | `You are not real` | `IO.write` |
| `gabs2` | `True{}` | direct `U32.add` |
| `gabs3`, `gabs5`, `transtyping` | `True{}` | fused traversal; `+value` instead of `U32.copy` |
| `gabs4` | `the texts are 61% alike (19 of 31 distinct words shared)` on `fixtures/` | IO (argv, files); unsupported in Core (no argv effect there); one structural tokenizer instead of five mutually recursive defs |
| `insertion_sort` | `True{}` | `+U32` keys; the comparison branch is a helper with a thunk |
| `integer_sqrt` | `True{}` | structural Nat fuel (no `#[halts]`) |
| `merge_sort` | `True{}` | `merge` counts down Nat fuel (no `#[halts]`) |
| `nat_proofs` | `-` | real `law`s with proofs: `add_n_z`, `add_n_s`, `add_assoc`, `add_comm`; `main_value` is the `add_n_z` instance, which `main` accepts erased |
| `tournament` | `True{}` | parallel lets restored (Core had none), `+Nat` depth (no `#[halts]`) |
| `tree_sort` | `True{}` | `+U32` keys; lazy `branch` helper |
| [`chip8/`](chip8/) | `True{}` (self-test `main_value`), or a ROM's framebuffer | IO shell loads `.ch8` files named in argv; pure Data machine |

`gabs3.bend` and `gabs5.bend` are thin imports of `transtyping.bend`, matching
the fact that the two Bend3 sources are intentionally identical.
`fixtures/` holds the two sample texts for `gabs4` (copied from
`Bend3/programs/fixtures/`).

All programs give the same output through `bend FILE`, a native build and
the JS build (re-run for every file after the merge). `nat_proofs` prints `-`
in all three; before the merge its `main` returned the equality and printed
`{==}`.

`chip8/` is a new program rather than a Bend3 port. It implements the classic
COSMAC VIP CHIP-8 instruction set; it does not compile Bend programs into
CHIP-8 bytecode.

## Migration notes (bend2-core to Bend 2.0.40)

- `type X:` became `type X is Data:`; U32 literals (`42`) replace
  `U32.from_nat(42n)`/`U32.zero()`/`U32.one()`; `U32.shln(x, n)` and
  `U32.shrn(x, n)` take the value first.
- Reuse is a quantity: `+x` on a Data value is reference-counted, so the old
  `((a, ea), (b, eb)) = U32.copy(x)` fan-out and structural copiers are gone.
- A `match` (and a destructuring let) takes only a parameter or a pattern
  variable, never a computed value or a let-bound local. Branches on a
  comparison therefore go through a helper def; where only one branch should
  run (recursive inserts, searches), the helper takes thunks `u => ...`.
- Recursion must be structural; there is no `#[halts]`. The old licensed
  programs now recurse on a reusable Nat (`+fuel`) or count down fuel.
- Defs are checked in file order and mutual recursion is refused, so helpers
  come first and mutually recursive groups become one def with a state value.
- The owner's Core revision moved several programs to explicit structural fuel
  (`integer_sqrt`, `merge_sort` with a combined-length fuel, `tournament`); the
  ports already did that, so only the `main_value` / IO `main` split was taken
  over. The owner's `main_value!()` is a plain `main_value()` here: in the
  latest Bend `f!(..)` means "run on the GPU".

## Reconciling with the owner's Core design

- `gabs4`: the owner's Core still lists it as unsupported because Core has no
  argv effect. The latest Bend has `IO.args`, so the port keeps the authored
  command-line interface and runs it (see `UNSUPPORTED.md`).
- `chip8`: the owner's Core keeps the hex-string ROM in `rom.bend` as the only
  input because Core lacks argv. Here `main` reads a `.ch8` file named on the
  command line; with no argument it prints the bundled ROM's self-check
  (`main_value()`), which is the owner's behaviour.
