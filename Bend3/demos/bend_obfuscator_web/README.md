# Bend3 Source Obfuscator

A private browser editor for turning readable Bend3 source into an equivalent,
harder-to-read Bend3 program. A compiled Bend3 HTTP server serves the tool; the
token-aware transformation runs locally in the browser, so pasted source is
never sent back to or retained by the server.

Aggressive mode combines several independent transformations instead of
depending on identifier renaming alone:

- **Three alias families:** long random runs, repeated programming-keyword
  lookalikes (`ifif`, `endd`, `elsee`, `addadd`, `defdef`, and similar), and
  mixtures of both. Every alias has unpredictable interior capitalization.
  Ordinary long English words are deliberately not used.
- **Layered integer encoding:** each eligible decimal `U32` expression literal
  becomes a randomized tree of additions, subtractions, multiplications,
  decompositions, and cancelling identities. Several templates and two to four
  identity layers prevent every literal from receiving the same recognizable
  replacement.
- **Procedural indirection:** an eligible helper is hidden behind two to four
  separately placed call layers. Each layer uses a constant-derived arithmetic
  selector whose branches preserve the same call, making local flow noisier
  without duplicating a performed effect.
- **Dead-code insertion:** two to five unreachable top-level `U32` identity
  helpers are generated. Their names and locations are mixed with the call
  layers.
- **Layout transformation:** generated declarations are shuffled and separated
  by irregular blank regions; existing inline whitespace grows to irregular
  gaps of up to 72 columns. Newlines and indentation are retained because Bend
  is indentation-sensitive.
- **Metadata removal:** ordinary comments can be removed while recognized Bend
  directives are retained.

Identifier renaming is always applied; every optional aggressive category has a
UI toggle. Every click uses a new seed, shown in the result; supplying the same
seed to the browser engine reproduces the output byte-for-byte.

Bend syntax, `main`, uppercase types and constructors, import lines, both
`Module.name` and `Module::name` qualified names, constructor field labels,
strings, character literals, floating-point and based-number literals,
directives, and C-bodied effect names remain protected. The editor can open or
accept dropped `.bend` files, display and filter the exact rename map, copy the
result, and download a source file.

Malformed string or character literals produce blocking diagnostics. The
interface deliberately calls the operation an **obfuscation transform**, not a
compile: only the actual Bend3 checker can establish that a complete program is
valid.

This is source obfuscation, not encryption or cryptographic protection. It
raises the effort required for casual reading but cannot hide an algorithm from
a determined reader or a sufficiently capable deobfuscator.

## Technique basis

The design follows the distinction between layout, control, and data
transformations in [Collberg, Thomborson, and Low's foundational
taxonomy](https://profs.sci.univr.it/~giaco/download/Watermarking-Obfuscation/Obfuscation%20Taxonomy.pdf).
The [OWASP MASTG obfuscation overview](https://mas.owasp.org/MASTG/knowledge/generic/MASVS-RESILIENCE/MASTG-KNOW-0111/)
motivates combining name transformation with varied instruction substitution,
control-flow transformation, and dead-code injection instead of treating
renaming as sufficient. The reproducible-seed design and the warning about
optimizer/deobfuscator recovery also reflect the practical engineering concerns
in the [2017 LLVM Developers' Meeting obfuscator
slides](https://llvm.org/devmtg/2017-10/slides/Guelton-Challenges_when_building_an_LLVM_bitcode_Obfuscator.pdf).

Those sources describe compiler-IR transformations with substantially more
semantic information than this browser tool possesses. This implementation
therefore does **not** claim full control-flow flattening, string encryption,
packing, tamper resistance, or cryptographic security. Its arithmetic selectors
and unreachable helpers are intentionally conservative source-level analogues.

## Run

From the repository root:

```sh
./gabriel_demos/bend_obfuscator_web/build.sh
./gabriel_demos/bend_obfuscator_web/start.sh
```

Open `http://<server-lan-ip>:8088`.

The tool is also mounted inside the single-process BendJogos hub at
`http://<server-lan-ip>:8090/obfuscator`.

## Equivalence boundary

The protected-name analysis remains deliberately conservative. C-backed effect
definition names are preserved because their generated `io_<name>` symbol is an
external ABI. Uppercase types and constructors and qualified module members are
also preserved so code using imported libraries remains valid. Constructor
field labels and their shorthand bindings are protected globally; this
sacrifices some obfuscation strength to avoid changing imported record layouts.

Call indirection applies only to simple one-line signatures whose bodies are
not self-recursive or C imports. Generated selector branches perform the same
call; the tool does not rewrite arbitrary user control flow. Decimal literals
in `case` patterns remain literal because patterns cannot be arithmetic
expressions. Floating-point, scientific-notation, and based-number forms are
left unchanged. Integer encoding is limited to values in the `U32` range and
constructs every intermediate inside that range.

Indirection and decoys increase source size, checking cost, and potentially
runtime cost. A compiler may simplify many arithmetic identities or remove
unreachable definitions, so the source can look much worse than the compiled
artifact. The output should still be checked with the same Bend3 revision and
flags as the input program.

The browser engine has a permanent regression check:

```sh
node gabriel_demos/bend_obfuscator_web/test_obfuscator.mjs
```

To also materialize and evaluate the fixed-seed regression fixture:

```sh
BEND_OBFUSCATOR_OUTPUT=/tmp/obfuscator-overhaul.bend \
  node gabriel_demos/bend_obfuscator_web/test_obfuscator.mjs
bun bend-ts/src/bend.ts /tmp/obfuscator-overhaul.bend --eval main
```

The fixture must evaluate to `42`.

Versioned Bend3 observations are recorded in
[`unexpected_behavior/README.md`](unexpected_behavior/README.md).
