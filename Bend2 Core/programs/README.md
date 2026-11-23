# Ported programs

These started as strict-affine ports of Gabriel's Bend3 programs for the old
`bend2-core`, and are now ported to the released Bend 2.0.40 (`bend`). They
keep the Core style: explicit Base calls (`U32.add`, `U32.is_le`, ...) rather
than operator sugar, and `Bool` self-checks for the pure programs. Every file
checks with `ALL PROOFS CHECK`, and none uses `#[halts]` (gone in Bend 2) or
`@unsafe`.

```sh
bend insertion_sort.bend               # check, then normalize main: True{}
bend insertion_sort.bend --check-only  # ALL PROOFS CHECK
bend insertion_sort.bend -o /tmp/isort && /tmp/isort   # native: True{}
bend insertion_sort.bend -o /tmp/isort.js && bun /tmp/isort.js
bend gabs4.bend fixtures/reference.txt fixtures/other.txt
```

| Bend3 source | result | important adaptation |
|---|---|---|
| `appop` | `True{}` | Nat-pattern dispatch in a helper (matches take parameters only) |
| `binary_search` | `True{}` | one `+Tree` shared by four probes; `Tree.copy` no longer needed |
| `gabs1` | prints `You are not real` | IO; was unsupported in Core |
| `gabs2` | `True{}` | direct `U32.add` |
| `gabs3`, `gabs5`, `transtyping` | `True{}` | fused traversal; `+value` instead of `U32.copy` |
| `gabs4` | prints `the texts are 61% alike (19 of 31 distinct words shared)` on `fixtures/` | IO (argv, files); was unsupported in Core; one structural tokenizer instead of five mutually recursive defs |
| `insertion_sort` | `True{}` | `+U32` keys; the comparison branch is a helper with a thunk |
| `integer_sqrt` | `True{}` | structural Nat fuel (no `#[halts]`) |
| `merge_sort` | `True{}` | `merge` counts down Nat fuel (no `#[halts]`) |
| `nat_proofs` | `{==}` | real `law`s with proofs: `add_n_z`, `add_n_s`, `add_assoc`, `add_comm` |
| `tournament` | `True{}` | parallel lets restored (Core had none), `+Nat` depth (no `#[halts]`) |
| `tree_sort` | `True{}` | `+U32` keys; lazy `branch` helper |
| [`chip8/`](chip8/) | `True{}` (self-test), or a ROM's framebuffer | IO shell loads `.ch8` files; pure Data machine |

`gabs3.bend` and `gabs5.bend` are thin imports of `transtyping.bend`, matching
the fact that the two Bend3 sources are intentionally identical.
`fixtures/` holds the two sample texts for `gabs4` (copied from
`Bend3/programs/fixtures/`).

Value-returning programs give the same answer through the normalizer
(`bend FILE`), a native build and the JS build; `nat_proofs` prints `{==}` in
all three (Core's C driver used to reject an equality-valued `main`).

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
