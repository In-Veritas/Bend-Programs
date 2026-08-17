# Bend3 Source Obfuscator: behavior record

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Obfuscator feature baseline: `ce6db5c045e986e87fc48b5068c170969d0d00d1`
- Correctness and workflow baseline: `7f3c0fc8593e3d5f689f08ac6bfcd8f29c47e341`
- Recorded: 2026-07-22
- Quality review recorded: 2026-07-27

No Bend3 compiler or runtime file was modified while implementing or testing
this demo.

## Known behavior: the HTTP loop requires `--no-halt`

The standalone server has the same long-lived mutual-recursion shape as the
other browser demos. At the feature baseline, checking without `--no-halt`
reports `NotBound: u32_serve` at `routed_send`; checking and native compilation
with `--no-halt` succeed.

This is the already documented whole-book-scoping mode distinction. Its exact
explanation and isolated MRE have one canonical home in
[`minecraft_web/unexpected_behavior/`](../../minecraft_web/unexpected_behavior/README.md).
The command for this specific source is:

```sh
git checkout ce6db5c045e986e87fc48b5068c170969d0d00d1
node bend-ts/src/main.ts gabriel_demos/bend_obfuscator_web/web_obfuscator.bend
```

The build script uses `--no-halt`; no workaround was applied to Bend3.

## No new compiler/runtime anomaly found

The source checked with `--no-halt`, compiled natively, served its page, and
the transformed example checked and evaluated to `42`. The identifier
transformation itself is browser code and therefore is not evidence about
Bend3 runtime semantics.

## Issue: imported constructor fields could be renamed

### Summary

The first transformer protected imported and qualified names but not lowercase
field labels used with an imported constructor. Renaming those labels can
change or invalidate a program.

### Detailed explanation and reproduction

At `ce6db5c045e986e87fc48b5068c170969d0d00d1`, paste a pattern such as:

```bend
import HTTP

def status(response: HTTP::Response) -> U32:
  match response:
    case Response{status, headers, body}:
      status
```

`Response` remains stable, but `status`, `headers`, and `body` enter the
ordinary global rename map. Those names describe the imported constructor
layout and cannot safely be invented by this module.

### Resolution

The transformer now recognizes constructor braces, gathers explicit and
shorthand field labels, and protects each gathered name globally. This is
deliberately conservative: a local variable sharing a field name also remains
readable rather than risking an invalid imported record pattern.

The permanent reproduction is:

```sh
node gabriel_demos/bend_obfuscator_web/test_obfuscator.mjs
```

It also checks literal preservation, directive preservation, comment removal,
ordinary local renaming, and malformed literals.

## Issue: the UI claimed to compile without invoking Bend3

### Summary

The original primary button said **Compile obfuscated source**, although the
browser performed only a lexical source transform. Unterminated literals were
also accepted and exported without a blocking diagnostic.

### Resolution

The operation is now labelled **Obfuscate source**. A safety report separates
lexical consistency from Bend checking, malformed literals block copy and
download, and the interface repeatedly instructs users to check the result
with the same Bend3 revision and flags. File open, drag/drop, filtered mapping,
clipboard fallback, download naming, and local draft recovery improve the
workflow without overstating its guarantees.

## Remaining equivalence boundary

- This remains a conservative lexical transform, not a Bend parser, checker,
  proof of equivalence, minifier, or encryption system.
- Because indentation is semantic, whitespace is deliberately preserved.
- Imported field-label protection reduces obfuscation strength in exchange for
  correctness.
- C-bodied effect definitions and import lines remain stable because their
  external ABI and module binding cannot be renamed locally.

## Quality-baseline verification

At `7f3c0fc8593e3d5f689f08ac6bfcd8f29c47e341`, the permanent engine
test passes, all embedded scripts parse, headless Chromium validates successful
and blocking transforms without page errors, all three Bend demo sources check
with `--no-halt`, and the full repository suite passes 506/506.
