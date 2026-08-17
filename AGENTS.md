# Bend Programs workspace

This repository publishes verified programs from sibling Bend implementations.
Do not assume that a source file still works after a language revision: check,
compile, and (when its result/runtime permits) run it before syncing.

## Repository map

- `Bend3/programs/` — small authored programs, current Bend3 syntax.
- `Bend3/demos/` — interactive native and web demos synchronized from
  `../bend3/gabriel_demos/`. Source, pages, build scripts, custom effects, and
  `unexpected_behavior/` logs are versioned. Generated native binaries are not
  required for newly added packages; rebuild them locally.
- `Bend2/` — older full Bend2 application examples; unrelated to Bend2 Core.
- `Bend2 Core/` — strict-affine ports targeting `../bend2-core`.

Paths under `Bend2 Core/` contain a space; quote them in shell commands.

## 2026-08-17 Bend3 synchronization

The remote was fetched and tested at upstream revision
`1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`. The sibling `../bend3` local
branch was intentionally not pulled/merged: it was 35 commits ahead and 1,603
commits behind upstream and also held authored working changes. Testing used a
clean detached worktree of `origin/main` with the authored demo/program folders
linked in. Preserve that separation until the owner chooses a reconciliation
strategy.

Current Bend3 changed the API substantially: use
`bun bend-ts/src/bend.ts`, explicit file-relative imports, dot-qualified
constructors, parenthesized type application, current IO/TCP/HTTP/JSON types,
and `IO.write` for raw output. The old `main.ts` entry is gone. The upstream
`io_main` annotation fix is present.

All 13 files in `../bend3/programas_gabriel` and the published compatibility
name `transtyping` were migrated. The published `check.sh` stages sources beside
the selected checkout's `bend-base`, which is required by strict relative
imports. Against `1ebc1acc` the 14 published programs passed check, C emission,
native build, and native execution; structured lists and trees now print too.

```sh
BEND_REPO=/path/to/upstream-bend3 ./Bend3/programs/check.sh
```

The 16 demo entries all checked, emitted C, and built natively. The 12
standalone HTTP services occupy ports 8080–8089, 8091, and 8092; the unified
hub served the changed routes on 8090. Its HTTP clients completed full Texas
and Belote hands, and all Bend3/Core catalog and browser checks passed. Builds
were performed in temporary output locations, so
tracked no-extension binaries remain historical and must not be used as
evidence.

Current install `IO.Op` rejects the demos' arbitrary old C-bodied effects.
`Clock.bend` now uses `IO.now_ms`, and `CommandGFX.bend` adapts the two old flat
command renderers to standard `IO/GFX`; historical effect C remains only as a
record. BendJogos cannot use import aliases as namespaces because imports merge
one global declaration book. `generate_modules.mjs` derives checked-in
hub-private dotted modules before every hub build. Always launch the hub from
the Bend3 repository root: its `IO.read_text` page paths are repository-root
relative.

The 2026-08-17 feature pass added classic Belote (`belote_web`), with Bend-owned
deal, bidding, legal play, tricks, scoring, random IO seeds, and three visibly
stepped computer seats. It no longer races from deal to a completed hand before
the browser can render it. It also added Poker (`poker_web`): selectable Texas
or Omaha, four seats plus a rotating dealer role, invitation tokens, ten AI
personas, private-card isolation, no-limit controls, and visible-information
browser odds. Poker deliberately documents that side-pot accounting is not yet
implemented.

Club Corvid now has original procedural Web Audio room/game songs, interaction
effects, Worm Hunt, and Echo Perch in addition to its original two games. No
external MIDI or recordings are used. The obfuscator now combines three
families of long mixed-case aliases, layered arithmetic literal encoding,
multiple shuffled call wrappers, opaque arithmetic selectors, unreachable
decoys, comment removal, and safe inline gaps up to 72 columns. It protects
qualified imports and non-decimal numeric tokens and documents why this remains
source obfuscation rather than encryption.

Sequential end-to-end native build times with the fetched `1ebc1acc` worktree
(`bun bend-ts/src/bend.ts SOURCE --no-halt -o OUTPUT`) were:

| Entry | Seconds |
| --- | ---: |
| `bar_bend` | 5.22 |
| `bar_window` | 4.49 |
| `elements` | 2.39 |
| `bar_web` | 25.42 |
| `elements_web` | 10.14 |
| `obfuscator` | 9.44 |
| `agar` | 13.84 |
| `club_corvid` | 22.34 |
| `cubeworld2` | 19.07 |
| `duck_hunt` | 14.42 |
| `minecraft` | 15.57 |
| `slither` | 15.35 |
| `tictactoe` | 13.29 |
| `belote` | 19.24 |
| `poker` | 21.44 |
| `bendjogos` | 145.93 |

These are single sequential wall-clock samples, not a statistically controlled
compiler benchmark. The fourteen entries shared with the preceding pass totaled
190.22 s versus 188.75 s (+0.78%, ordinary run noise); the larger hub is slower
because it now includes Poker, not evidence of a compiler regression.

Current issue results are recorded in each `unexpected_behavior/` log. In
particular, later-definition scoping is fixed, but a reachable two-function
nonterminating cycle is accepted by default checking. Expression-style
`if condition { ... }` remains a parse error; use `match`.

## Bend2 Core work

The Core work targets commit `26cddb7`. Read `Bend2 Core/GUIDE.md` before
editing; it contains the detailed second audit. Core is affine (at most once),
not exactly-linear. Sequential uses add, mutually exclusive branch uses join,
and dead type/proof/motive positions do not spend a live value. Explicit copies
such as `U32.copy`, `Nat.copy`, or structural data copiers have real data cost
even though their equality proofs erase.

Twelve pure authored programs have ports. `gabs1` and `gabs4` are
recorded as unsupported because Core lacks an effect runtime. Complete
interactive demos are likewise blocked, but pure observer ports of Poker and
Belote now compile reports to JS; see `Bend2 Core/demos/README.md`.

## Bend2 Core Poker and Belote observers

`Bend2 Core/demos/poker/` returns deterministic Texas and Omaha timelines for
four AIs. Every step includes all private cards, action/pot/stack state, best
hand labels, and four win/category odds columns. `Bend2 Core/demos/belote/`
returns a seeded four-AI bidding/play timeline with all 32 cards, follow/cut/
overtrump legality, all eight trick winners, and the verified 47–115 result.
Both programs are affine, use no `#[halts]`, and contain no IO. Their browser
pages only decode and animate the immutable values emitted by Core's JS backend.
The final sequential JS artifact builds took 0.43 s for Poker and 0.86 s for
Belote. Their generated SHA-256 values were respectively
`bf9d448132e45aa4d2e357b5cea538a4b988aac4d67548f33b40b8e3950d4bee`
and `aacef18cc9971a6ab69c70ef04d986a002f008014f1e2e2ad6203a78d1ceb498`.

Rebuild and independently validate them from their package directories:

```sh
./build.sh
bun test.mjs
```

`bendjogos_web/sync_core.mjs` copies these checked-in generated assets into the
hub. The Bend3 server is only their HTTP shell: `/core/poker` and
`/core/belote` are Core computations, while `/poker` and `/belote` are the
interactive Bend3 versions. Keep that capability boundary explicit until Core
implements IO.

Check a port and verify its JS backend from `../bend2-core`:

```sh
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/tree_sort.bend"
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/tree_sort.bend" --to /tmp/tree_sort.js
bun /tmp/tree_sort.js
```

Do not directly normalize `tournament.bend`; use `--to`. Its normal form
expands structural U32 operations and was still consuming CPU after 18 minutes,
whereas both generated backends finish immediately.

Computational ports return `True{}` in both generated JS and C. `nat_proofs`
normalizes to `{==}` and compiles to erased JS output `-`; the C emitter rejects
an equality-valued `main` because its driver supports only String, Bool, Nat,
U32, and Char. `integer_sqrt`, `merge_sort`, and `tournament` use `#[halts]`;
their files explain why Core's syntactic termination checker cannot certify the
copied or alternating structural descent.

`#[halts]` is an unsafe whole-book license, not a local annotation. Any licensed
import enables whole-book scope, forward/mutual references, unchecked recursive
descent, live unfilled assertions, and self references as values. Avoid it when
a structurally checkable program is practical.

The C/JS compilers erase proofs and recognize canonical Base operations by
name. That intrinsification is why U32-heavy programs can normalize slowly but
run immediately after lowering. The C driver only prints String, Bool, Nat,
U32, or Char and does not execute `IO.OP`; the JS backend may merely print an
effect tree.

## CHIP-8 emulator

`Bend2 Core/programs/chip8/` is a new pure emulator, not a Bend-to-CHIP-8
compiler. It implements the classic COSMAC VIP instruction set over a 4 KiB
RAM array, 16 registers, 12-entry checked stack, 64×32 XOR framebuffer, keys,
timers, deterministic xorshift random state, and explicit Running/Waiting/
Releasing/Halted status. `0NNN` host-machine calls are reported unsupported; SUPER-CHIP
and XO-CHIP are out of scope.

Because Core has no host input, `rom.bend` exports a whitespace-separated hex
String which is parsed and loaded at `0x200`. The README has a required note to
remove this embedded-ROM bridge when IO exists. `machine_key` is the future
input seam. The bundled ROM checks arithmetic/carry, BCD, call/return, original
shift behavior, random masking, font lookup/drawing, timer behavior, key skip,
PC/I, stack, and framebuffer. The implementation uses no `#[halts]`.

The emulator returned `True{}` through direct normalization, generated JS, and
a clang-built native C executable. Re-run from `../bend2-core`:

```sh
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/chip8/chip8.bend"
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/chip8/chip8.bend" --to /tmp/chip8.c
clang -O2 /tmp/chip8.c -o /tmp/chip8 && /tmp/chip8
```

## Editing discipline

- Keep `unexpected_behavior/` logs strictly about behavior attributable to the
  Bend parser, checker, compiler, Base/runtime, backend, or documented language
  modes. Do not record macOS/Metal/Chromium sandbox incidents, browser policy,
  firewall/LAN/port/process problems, network timing, test-harness state leaks,
  ordinary application bugs, UX gaps, or demo security/feature limitations as
  Bend issues. Operational instructions may remain in ordinary READMEs when
  users need them to run a program.
- Preserve every `unexpected_behavior/` log when syncing demos; they are part
  of the purpose of this repository.
- Do not copy a stale checked-in native binary over a newly verified source.
  Rebuild artifacts from the matching compiler revision.
- Keep unsupported ports explicit in the status docs instead of presenting a
  checker-only effect tree as a runnable application.
- Regenerate BendJogos modules after changing a standalone demo, then check the
  standalone entry and the unified hub.
- Before changing Core code, read `../bend2-core/AGENTS.md`; before changing
  Bend3 code, read `../bend3/AGENTS.md`.
