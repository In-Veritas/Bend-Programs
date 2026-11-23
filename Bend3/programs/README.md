# Published Bend programs

Small Bend programs, ported to the released **Bend 2.0.40** CLI on
2026-11-23. They use the current surface: `import Base`, `type X is Data:`,
bare constructor names (`Leaf{}`, `h <> t`, `0n`, `1n+p`), annotated
operators (`(a + b : U32)`), `+x` for reusable values, and `match` only on
parameters or pattern variables (a computed comparison is handed to a small
helper that matches the resulting `Bool`). Every file checks with
`ALL PROOFS CHECK`: recursion is structural, there is no mutual recursion
and no `@unsafe`.

```
.              the programs -- all 14 pass every stage
fixtures/      sample texts for gabs4
check.sh       run everything and report a diagnosis
```

Install Bend (`curl -fsSL https://bend-lang.com/install.sh | sh`), then:

```
bend insertion_sort.bend --check-only   # check proofs, types and termination
bend insertion_sort.bend                # check, then run main and print it
bend insertion_sort.bend -o isort.c     # emit the standalone C file
bend insertion_sort.bend -o isort       # build a native binary (needs clang)
./isort

bend gabs4.bend fixtures/reference.txt fixtures/other.txt   # IO main, with args
```

A value-returning `main` is normalized by the checker and printed; an `IO`
`main` is compiled and run. A native binary of a value `main` prints the same
value.

## check.sh

```
./check.sh                  # every program, every stage
./check.sh -v               # with full error text for failures
./check.sh --no-native      # just CHECK and RUN
./check.sh some/other/dir   # another folder of .bend files
BEND=/path/to/bend ./check.sh
```

It uses the `bend` on `PATH` (or `$BEND`) and walks five stages per program:
CHECK (`bend f.bend --check-only`, must print ALL PROOFS CHECK), RUN
(`bend f.bend [args]`), C (`bend f.bend -o f.c`), BUILD (`bend f.bend -o f`)
and NATIVE (run the binary). RUN and NATIVE must match the file's `# expect:`
line, and NATIVE must match RUN. Build outputs go to a temporary directory
that is removed afterwards. It exits non-zero if any stage fails. On the
2026-11-23 run with bend 2.0.40 all 14 programs passed all five stages.

Per-file pragmas, read from comment lines:

| pragma | effect |
|---|---|
| `# run-args: a.txt b.txt` | argv for RUN and NATIVE, run from the `.bend` file's folder |
| `# stdin: file.txt` | feed a file to RUN's and NATIVE's stdin |
| `# expect: text` | the first output line RUN and NATIVE must print |
| `# skip-native` | check and run only |

## The programs

| | what it does | result |
|---|---|---|
| `gabs2` | adds two numbers | `5` |
| `gabs3`, `gabs5`, `transtyping` | LeafTree → NodeTree (identical programs) | `Node_{Node_{Leaf_{}, Leaf_{}, 1}, Leaf_{}, 1}` |
| `gabs1` | prints a line through the IO monad | `You are not real` |
| `gabs4` | Jaccard vocabulary overlap of two text files (IO: args + file reads) | `the texts are 61% alike (19 of 31 distinct words shared)` on the fixtures |
| `insertion_sort` | insertion sort | `[1, 2, 3, 4, 5, 6, 7, 8, 9]` |
| `tree_sort` | BST insert + in-order readback | `[1, 3, 7, 10, 19, 24, 42, 56, 61, 88]` |
| `merge_sort` | bottom-up binary-counter merge sort | `[1, 2, 3, 4, 5, 6, 7, 8, 9]` |
| `integer_sqrt` | 16-probe binary search over the root's bits | `[0, 1, 9, 10, 1000, 65535]` |
| `binary_search` | one shared tree, four probes | `[1, 0, 1, 0]` |
| `tournament` | parallel single-elimination bracket | `995` |
| `appop` | branchless operator dispatch (from `demo/calc.bend`) | `86` |
| `nat_proofs` | refl, rewrite, induction over Nat (a `law` and its proof) | `{==}` |

`appop` and `nat_proofs` are worked migration examples rather than originals;
they remain because they exercise useful arithmetic and proof surfaces.
`transtyping` preserves the earlier published name for the program also kept as
`gabs3` and `gabs5` in the authored set.

## Notes on the 2.0.40 port

- Comparisons return `Bool`, not 0/1: branchless code (`appop`, `tournament`,
  `gabs4`) turns them into numbers with `Bool.to_u32`, and equality is
  `U32.is_eq(a, b)` (`==` is only the equality type).
- Where a comparison picks a recursive branch (`insertion_sort`, `tree_sort`,
  `binary_search`, `merge_sort`), the recursive calls are passed to the helper
  as thunks (`u => insert(n, l)`), the idiom Base's `List.any` uses, so only the
  chosen branch is evaluated.
- Counters that used to be `U32` matched with `1+i` (`integer_sqrt`,
  `tournament`) are now `Nat` (`16n`, `6n`), which makes them structural.
- `gabs3`/`gabs5`/`transtyping` inline their former mutually recursive helper
  `node_to_nodetree`; `gabs4`'s five-state tokenizer became one def `tok` whose
  per-character step receives the rest of the walk as a closure, and it uses
  `U32.show`, `String.eq` and `List.contains` from Base. It reads files with
  `File.open`/`File.size`/`File.read` (there is no `IO.read_text`).
- `nat_proofs` uses Base's `Nat` with its own `add`, and states `add_n_Z` as a
  `law` proven by induction and rewrite.
