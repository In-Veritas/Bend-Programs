# Bend3 Source Obfuscator: Bend behavior

## Reproduction revisions

- Bend3 package version: `0.1.0`
- Historical compiler/base revision:
  `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Obfuscator feature baseline: `ce6db5c045e986e87fc48b5068c170969d0d00d1`
- Current retest revision: `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`

No Bend3 compiler or runtime file was modified while implementing or testing
this demo.

## Historical behavior: the HTTP loop required `--no-halt`

The standalone server has the same long-lived mutual-recursion shape as the
other browser demos. At the feature baseline, checking without `--no-halt`
reported `NotBound: u32_serve` at `routed_send`; checking and native compilation
with `--no-halt` succeeded.

The language behavior and isolated reproduction have one canonical home in
[`minecraft_web/unexpected_behavior/`](../../minecraft_web/unexpected_behavior/README.md).
The build script retains `--no-halt`; no workaround was applied to Bend3.

## Current verification

At `1ebc1acc`, the server source checks and compiles. Two distinct fixed-seed
obfuscator outputs both check and evaluate to `42`. No new Bend parser,
checker, compiler, or runtime anomaly was found during the obfuscator overhaul.
