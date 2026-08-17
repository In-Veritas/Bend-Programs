# BendJogos Web Hub: issues and unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Demo integration baseline: `317e82a9a16cd0893a946d1b79af15cbc5e05a8b`
- Unified native binary baseline: `0ec035d`
- Expanded hub baseline (CubeWorld 2, Club Corvid, and obfuscator):
  `bcdaf0a1cfcd0d05571912819121a99feedf62f4`
- Duck Hunt source expansion:
  `efdc6c4a63bdf1f9e3fea7f798c84b13b2e07a9d`
- Duck Hunt unified native binary:
  `34c68e21161fd520feebe66b36866445f97714d4`
- Recorded: 2026-07-22

## Issue: six independent servers prevented a coherent hub

### Summary

The first platform started separate binaries across ports `8080` through
`8090`. Routes needed different origins, firewall configuration expanded, and
game and social state could not share one owner.

### Resolution

`web_bendjogos.bend` imports the game modules, owns every state value, and
serves every route from one Bend process on port `8090`.

## Issue: parent-relative modules broke C-effect lookup

### Summary

The Bend loader found a parent-relative `.bend` module, but `book_eff` removed
the first two characters from its import identifier. Importing `../Clock` made
`../effs/now_ms.c` resolve as `.//effs/now_ms.c` under the wrong directory.

### Minimal reproduction

Import a parent module which itself declares a C-bodied effect, then check or
compile the importing program.

### Resolution

`bend-ts/src/bend.ts` preserves the `../` prefix while routing the effect
through the local-file reader.

## Issue: duplicated clock effects collided during composition

### Summary

Snake Arena and Cell Arena each declared their own realtime clock effect. They
worked alone but produced duplicate constructors when imported together.

### Resolution

The clock has one home in `gabriel_demos/Clock.bend`.

## Issue: an effect name collided with a generated runtime C symbol

### Summary

Naming the shared effect `now_ms` generated `io_now_ms`, which collided with
the runtime's existing helper of the same name. Bend type-checking succeeded;
the native C compiler reported conflicting declarations.

### Resolution

The effect is named `clock_now_ms`, producing `io_clock_now_ms`. A native build,
not only a Bend check, is required when adding C-bodied effects.

## Issue: filtered JSON arrays emitted a leading comma

### Summary

The initial social emitters returned invalid JSON such as
`[,{"name":"alice"}]` when a filtered array became non-empty. Empty arrays
looked correct and allowed shallow tests to pass.

### Resolution

The emitters explicitly track whether an included item is the first. The
two-account acceptance test parses every response with `JSON.parse` and covers
friend requests, acceptance, presence, chat, and invitations.

## Issue: the combined generated C is expensive to optimize

### Summary

The unified source checks and emits C quickly, but the single `clang -O3` build
is substantially larger and slower than any individual demo build.

### Status

This is an observed cost of intentionally producing one native binary. The
runtime was not complicated to compensate; the build script remains the
canonical build path.

### Expanded-hub measurement

At integration revision `bcdaf0a1cfcd0d05571912819121a99feedf62f4`, the
canonical command:

```sh
./gabriel_demos/bendjogos_web/build.sh
```

took approximately 76 minutes on the arm64 development Mac. Nearly all of
that time was spent by one `clang -O3` process optimizing the generated
monolithic C file. The process continuously used approximately one CPU core;
its observed memory use varied between about 21% and 39%, so duration alone
was not evidence of a stalled build. The successful executable is 40,654,688
bytes.

The same expanded Bend source checked successfully in under a second, and the
full repository suite passed 506/506 in 9.4 seconds. No Bend3 compiler or
runtime source was changed to reduce or conceal the native build cost.

### Duck Hunt expansion measurement

At source revision `efdc6c4a63bdf1f9e3fea7f798c84b13b2e07a9d`, adding the
Duck Hunt backend increased the same canonical unified build to approximately
100 minutes on the arm64 development Mac. The compiler remained active at
approximately one full CPU core throughout. Observed memory moved from about
4% early in optimization, through a peak near 46%, and down below 9% during a
late phase before a successful link.

The resulting binary at
`34c68e21161fd520feebe66b36866445f97714d4` is 44,592,704 bytes. The
expanded Bend source still checked in under one second, and the full repository
suite passed 506/506 in 9.3 seconds. Duration alone was again not evidence of a
stalled compiler.

### Club Corvid catalog expansion measurement

At Club Corvid source revision
`a4f5f740eae4b2cba88f2c26e0586c5439062d8d`, adding authoritative currency,
inventory, buying, equipment, and minigame payouts produced another successful
canonical unified build:

```sh
./gabriel_demos/bendjogos_web/build.sh
```

The build took approximately 96 minutes on the same arm64 development Mac.
The single `clang -O3` process remained near one full CPU core throughout;
sampled memory use included 14% at 55 minutes and 32.5% at 87 minutes. It
finished without diagnostics and linked a 47,550,288-byte executable.

The exact generated artifact is committed at
`6821ac5204edba0a55ef0663faa833fa94d7c379`. Before the native build, the
unchanged compiler checked the unified source with `--no-halt`, and the full
repository suite passed 506/506. After linking, the binary served the hub and
Club Corvid page through port 8090 and completed join, catalog purchase, and
equipment actions through the `/club-corvid` prefix.

## Limitation: social state is intentionally volatile

Accounts, sessions, friendships, messages, invitations, and presence are held
in the server's immutable state value and disappear when the process restarts.
This is demo scope, but it is externally visible and must not be mistaken for
persistent account storage.

## Verification environment: sandboxed Chromium launch was denied

### Summary

The first headless browser test attempt could not launch Chromium inside the
managed macOS process sandbox. The browser terminated before opening any demo,
so this was a test-environment permission failure rather than evidence of a
page or Bend3 failure.

### Detailed observation

The failing launch reported:

```text
MachPortRendezvousServer: Permission denied (1100)
```

The identical Playwright test command succeeded outside that process sandbox:
CubeWorld controls, Club Corvid movement and both minigames, the obfuscator's
success/error flows, and the Club Corvid phone layout passed 4/4 without page
errors.

### Status

Browser automation on this managed Mac must be granted GUI/process launch
permission. No demo, Bend3 compiler, or runtime change is associated with this
environmental requirement.

## 2026-08-17 retest against upstream `1ebc1acc`

The upstream `io_main` annotation fix is present and the old pending-effect
startup failure is gone. Current import aliases are tooling metadata rather
than namespaces, however, so directly importing all standalone games produces
duplicate declarations such as `Game` and `clamp0`. The hub now runs
`generate_modules.mjs` to derive hub-private dotted declarations while keeping
the standalone sources independently compilable.

The generated hub checked, emitted 12,643,205 bytes of C, built a
24,075,560-byte native executable, and returned HTTP 200 from port 8090. This
current build is substantially smaller and faster than the historical
40–47 MB, 76–100 minute artifacts recorded above; those measurements remain
valid only for their named revisions.
