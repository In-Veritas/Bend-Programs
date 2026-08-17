# Ported programs

| Bend3 source | Bend2 Core result | Important adaptation |
|---|---|---|
| `appop` | runnable | named U32 operations and Nat-pattern dispatch |
| `binary_search` | runnable | explicit structural `Tree.copy` for four probes |
| `gabs2` | runnable | direct `U32.add` |
| `gabs3`, `gabs5`, `transtyping` | runnable | fused traversal plus explicit U32 copying |
| `insertion_sort` | runnable | explicit head copies; structural argument first |
| `integer_sqrt` | runnable | Nat fuel, U32 copies, `#[halts]` |
| `merge_sort` | runnable | explicit head copies, `#[halts]` |
| `nat_proofs` | checker/evaluator proof | Core equality and rewrite syntax |
| `tournament` | runnable sequentially | explicit state/depth copies, no fork, `#[halts]` |
| `tree_sort` | runnable | explicit key copies; structural argument first |
| [`chip8/`](chip8/) | runnable emulator | imported hex-ROM string, pure VM state, deterministic headless IO seams |

`gabs3.bend` and `gabs5.bend` are thin imports of `transtyping.bend`, matching
the fact that the two Bend3 sources are intentionally identical.

`chip8/` is a new Bend2 Core program rather than a Bend3 port. It implements
the classic COSMAC VIP CHIP-8 instruction set and compiles the Bend emulator to
JavaScript or native C; it does not compile Bend programs into CHIP-8 bytecode.
