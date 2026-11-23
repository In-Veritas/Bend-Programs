# Bend2 Core unexpected behavior

## Base U32 constants do not emit to C

`u32_constant_c_emission.bend` uses only public definitions from the current
Base library. First verified at `c5b919ab161f42815503164d7864ae3c82c72147`
and reproduced at `c5d69a14608b93896b5046e310d501903235d6c8`.

Run from the Bend repository:

```sh
bun bend2/comp.ts \
  "../Bend-Programs/Bend2 Core/unexpected_behavior/u32_constant_c_emission.bend"

bun bend2/comp.ts \
  "../Bend-Programs/Bend2 Core/unexpected_behavior/u32_constant_c_emission.bend" \
  --to /tmp/u32-constants.js
bun /tmp/u32-constants.js

bun bend2/comp.ts \
  "../Bend-Programs/Bend2 Core/unexpected_behavior/u32_constant_c_emission.bend" \
  --to /tmp/u32-constants.c
```

Expected: every lane prints `1`, and C emission succeeds because `U32.zero`
and `U32.one` are filled public Base definitions.

Actual: the interpreter and JavaScript output `1`; C emission fails with:

```text
Error: tocl: a structural view of a machine word (report this case)
```

The C compiler recognizes most U32 operations as machine-word intrinsics but
does not recognize the two constant definitions. Inlining their Base bodies
exposes the otherwise intentionally unsupported `U32{Word(...)}` structural
representation. Authored programs use the equivalent current U32 literals
`0` and `1` until the Base/compiler seam is fixed.

## Retest on the latest Bend (bendlang/bend source, `bend 2.0.40`)

The original MRE (kept unchanged above, old `assert` syntax) no longer parses,
and its premise is gone: the latest Base has no `U32.zero` / `U32.one` at all
(`bend base U32.zero` answers "Base has no U32.zero"; calling it reports
`expected: a defined name`). U32 literals (`0`, `1`) are the public spelling.

`u32_constant_c_emission_latest.bend` is the current-syntax analogue: the two
constants are ordinary defs (`0` and `U32.from_nat(1n)`). It does **not**
reproduce:

```sh
bend u32_constant_c_emission_latest.bend                 # 1
bend u32_constant_c_emission_latest.bend -o /tmp/u.c     # C emitted
bend u32_constant_c_emission_latest.bend -o /tmp/u && /tmp/u     # 1
bend u32_constant_c_emission_latest.bend -o /tmp/u.js && bun /tmp/u.js  # 1
```

No `tocl: a structural view of a machine word` error occurs; the issue is
resolved (by removal of the two Base constants) and needs no bug report.
