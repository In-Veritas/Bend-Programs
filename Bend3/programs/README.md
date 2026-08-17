# Published Bend3 programs

Bend programs verified against upstream Bend3 revision `1ebc1acc` on
2026-08-17. They use the current `def`/`type`/`match` surface, explicit
file-relative Base imports, dot-qualified names, generic `T` parameters, and
`+T` shared arguments.

```
.              the programs, in current syntax -- all 14 pass every stage
fixtures/      sample texts for gabs4
check.sh       run everything and report a diagnosis
```

Run them with this checkout, or point the script at another Bend3 revision with
`BEND_REPO`:

```
./check.sh                         # run every program, report where each got to
./check.sh -v                      # with full error text for failures
./check.sh --no-native             # skip compile/build/run, just typecheck
BEND_REPO=/path/to/bend3 ./check.sh
```

`check.sh` stages the selected folder beside the chosen checkout's `bend-base`
because current imports are strictly file-relative. It then walks four stages
per program — CHECK (parse/typecheck/interpret),
COMPILE (emit the standalone C file), BUILD (clang it), RUN (execute it) — and
reports the interpreted result plus the native output.

Current native rendering handles the structured list and tree answers used by
this set. The 2026-08-17 run at `1ebc1acc` passed all four stages for all 14
programs.

Per-file pragmas, read from comment lines:

| pragma | effect |
|---|---|
| `# no-halt` | pass `--no-halt` (non-structural or mutual recursion) |
| `# run-args: a.txt b.txt` | argv for the native run, relative to the `.bend` file |
| `# stdin: file.txt` | feed a file to the native run's stdin |
| `# skip-native` | check only |

## The programs

| | what it does | result |
|---|---|---|
| `gabs2` | adds two numbers | `5` |
| `gabs3`, `gabs5`, `transtyping` | LeafTree → NodeTree (identical programs) | `Node_{Node_{Leaf_{},Leaf_{},1},Leaf_{},1}` |
| `gabs1` | prints a line through the IO monad | `You are not real` |
| `gabs4` | Jaccard vocabulary overlap of two text files | `61% alike (19 of 31 distinct words shared)` on the fixtures |
| `insertion_sort` | insertion sort | `[1,2,3,4,5,6,7,8,9]` |
| `tree_sort` | BST insert + in-order readback | `[1,3,7,10,19,24,42,56,61,88]` |
| `merge_sort` | bottom-up binary-counter merge sort | `[1,2,3,4,5,6,7,8,9]` |
| `integer_sqrt` | 16-probe binary search over the root's bits | `[0,1,9,10,1000,65535]` |
| `binary_search` | one shared tree, four probes | `[1,0,1,0]` |
| `tournament` | parallel single-elimination bracket | `995` |
| `appop` | branchless operator dispatch (from `demo/calc.bend`) | `86` |
| `nat_proofs` | refl, rewrite, induction over Nat | `{==}` |

`appop` and `nat_proofs` are worked migration examples rather than originals;
they remain because they exercise useful arithmetic and proof surfaces.
`transtyping` preserves the earlier published name for the program also kept as
`gabs3` and `gabs5` in the authored set.
