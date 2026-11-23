# Native build dies with "an arity over 247" (no location) for wide Data records

## Description

A program that checks (ALL PROOFS CHECK) and runs on the JS lane (`bend
mre.bend` prints `done`) cannot be compiled natively: `bend mre.bend -o x`
(and `-o x.c`) stops with the single line `Error: an arity over 247`, naming
no def, segment, type or source line.

The backend flattens a `Data` value into machine words (`lay_of` in
`bend2/comp.ts`). A record of 100 `U32` fields is 100 words; a record of
three of them (`Trio`, 300 words) is boxed, but the tuple/continuation
plumbing around it (`put(r: Big & U32, b: Big, c: Big)` called from an
`IO.bind` lambda) produces a segment with more than 247 parameter words,
and `c_header` dies (`comp.ts`, `die("an arity over " + WIDE)`).

Expected: either the backend boxes values to stay under its limit (as
`lay_of` already does for one oversized type), or the error names the def
whose segment is too wide so the user can restructure it.
Actual: a location-free fatal error at C emission, after a successful check.

## Reproduce

```sh
bend mre.bend --check-only   # ALL PROOFS CHECK
bend mre.bend                # done
bend mre.bend -o /tmp/mre    # Error: an arity over 247
```

## Output

```
$ bend mre.bend --check-only
ALL PROOFS CHECK
Use --verdict for mathematical validity.
$ bend mre.bend
done
$ bend mre.bend -o /tmp/mre
Error: an arity over 247
```

## Environment

- `bend 2.0.40` (latest bendlang/bend source, HEAD 6b806192, run from source)
- Linux x86_64
- Ubuntu clang version 21.1.8

## Workaround used in the port

`Bend3/demos/bendjogos_web/web_bendjogos.bend` (the hub holding 14 game
states) hit it. Each game state is wrapped in a self-referential type, which
`lay_of` always boxes, so every Platform field is one word:

```python
type Held<-A: Data> is Data:
  Hold{value: A}
  Again{inner: Held<A>}
```

The hub build also peaked at about 15.7 GB RSS (17 GB on the failing
attempt) and 1 min 19 s wall time.
