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

The fetched `1ebc1acc` tree changed the API substantially: use
`bun bend-ts/src/bend.ts`, explicit file-relative imports, dot-qualified
constructors, parenthesized type application, current IO/TCP/HTTP/JSON types,
and `IO.write` for raw output. The old `main.ts` entry is gone in that fetched
revision. The upstream
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

## 2026-08-26 Bend2 Core synchronization

Upstream force-updated `main` from the earlier handoff history to revision
`c5d69a14608b93896b5046e310d501903235d6c8`. It was tested in a clean detached
worktree because the sibling `../bend2-core` checkout intentionally remains at
the old authored state. Use `bun bend2/comp.ts`; the old `src/` entry is gone.
The current revision requires every definition to have a preceding `assert`,
requires compiled `main` to be
`IO<T>`, adds a real interpreter/JavaScript/C IO loop, and replaces unchecked
ordinary sharing with the proof-gated `Cop`/`Copiable` surface. The pruned Base
no longer supplies the older `List.length`, `List.append`, `Nat.mod`, or
`Nat.is_eq` helpers; repository-local compatibility modules provide those
operations for the migrated programs.

Read `Bend2 Core/GUIDE.md` before editing. Core is affine (at most once), not
exactly-linear. Sequential uses add, mutually exclusive branch uses join, and
dead type/proof/motive positions do not spend a live value. A reusable `+`
binder always requires valid copy evidence; the old `#[halts]` whole-book
escape hatch no longer exists. Explicit copies such as
`U32.copy`, `Nat.copy`, or structural data copiers still have real data cost
even though their equality proofs erase.

Thirteen authored programs now have runnable ports, plus the CHIP-8 emulator.
`gabs1` uses the new `IO.write`; only `gabs4` remains explicitly unsupported
because Core has no argv API. The browser demos retain pure simulation/report
kernels and use `IO<Unit>` only at executable wrappers. Core now has standard
print, environment, file, TCP and UDP effects, but still has no clock, HTTP/
JSON, DOM, WebGL, audio, argv or browser-event layer; see
`Bend2 Core/demos/README.md`.

Two Bend backend defects first found during the earlier migration remain
reproducible at `c5d69a1`. Public
`U32.zero()`/`U32.one()` evaluate in the interpreter and JavaScript but C
emission exposes their structural word representation and fails; use contextual
`0`/`1` literals and retain the minimized case in
`Bend2 Core/unexpected_behavior/`. An erased equality binder can also escape a
compiled recursive continuation: the interpreter/JS reference an omitted
variable and C reports an unbound `~`. Bendy Birds keeps the minimized case in
its `unexpected_behavior/` directory and factors the composition into a named
proof theorem as a semantics-preserving workaround. Do not misclassify the new
browser compiler's reachability pruning as a defect: browser builders must
provide explicit temporary IO roots for pure functions exported to JavaScript.

## Bend2 Core observers

`Bend2 Core/demos/poker/` returns deterministic Texas and Omaha timelines for
four AIs. Every step includes all private cards, action/pot/stack state, best
hand labels, and four win/category odds columns. Its semantic proof kernel
shows that every arbitrary finite betting/payout history preserves the full
ordered chip identity/value payload; chip-count and total-value conservation
are corollaries. Three smaller deal lemmas cover arbitrary index lists and
complete round counts. Its 78 closed certificates cover selected
runouts and strategies change the winner in its finite model; every seat has a
witness; published category/win rows normalize; folded seats have zero equity;
and showdowns agree with their declared winners. Keep the README's strict
caveat: the 78 certificates are not mathematical poker-fairness or real-world
probability proofs.
`Bend2 Core/demos/belote/`
returns a seeded four-AI bidding/play timeline with all 32 cards, follow/cut/
overtrump legality, all eight trick winners, and the verified 47–115 result.
Its arbitrary-history semantic proof preserves every card identity and printed
point value through deals, plays and trick collection; card count and point
mass are corollaries. A supporting theorem proves snapshot-list length
preservation over arbitrary index lists. Its 119 closed certificates cover every deck position
and play, every seat and trick, exact ownership/legality/winner/point claims,
and the one embedded report shape.
Both kernels are affine and structurally terminating; their executable wrappers only
print readiness. Their browser pages decode and animate immutable values
emitted by Core's JS backend.
The generated `c5d69a1` browser artifacts have SHA-256 values
`0fd847f44d61cc00d3b625e1e77a752adfbafd73d9584107d52f4b4f9c25b320`
for Poker and
`3b5a7afbfe428526fa304d163e01a7c85a804283908921c7c17e870f2a899c19`
for Belote.
Rebuild and independently validate them from their package directories:

```sh
./build.sh
bun test.mjs
```

`bendjogos_web/sync_core.mjs` copies these checked-in generated assets into the
hub. The Bend3 server is only their HTTP shell: `/core/poker` and
`/core/belote` are Core computations, while `/poker` and `/belote` are the
interactive Bend3 versions. Keep that computation/presentation boundary
explicit; Core's standard IO does not provide the hub's HTTP/browser layer.

`Bend2 Core/demos/bend_a_beet/` contains three reusable pure libraries plus the
integrated game. Physics uses Q10; graphics and ray tracing use Q24.8, bridged
with `Graphics.fixed_from_q10`. The fixed seed produces a mixed 3 × 8 field and
a 1,086-frame report: one hundred 50 ms growth frames, sixteen simultaneous
uproot frames, fifty 50 ms response samples plus a terminal frame for each
planted beet, and a final state. Seven semantic theorems cover arbitrary motion
histories, arbitrary surface/light contract scenes, and exact Bend Engine
profile alignment; thirteen smaller original/Engine library lemmas support
them. Focused tests consume all 20 erased theorems plus 35 closed certificates.
The scene theorem requires positive reflectance and
positive incident light, produces one positive reflection witness and one
clear-or-occluded shadow evaluation per declared pair, and does not claim every
object is visibly dark. The six seeded material attributes include `shine`; Core
computes roughness, specular response, absorption, high-poly mesh quality,
world-space shadow anchors, four procedural texture classes, ambient/
directional/point/spot lighting, fog, reflection, fuzz, fur, and soft-shadow
controls. The browser controls select immutable frames or reproject Core points
and must not be described as Core IO. Keep `bend_a_beet_camera.js`,
`bend_a_beet_webgl.js`, and
`bend_a_beet_viewer.js` synchronized with the viewer page and BendJogos route.
The WebGL layer uses perspective depth, 3D ellipsoids/tubes/leaves, actual fur
strand tubes, procedural surface patterns, reflected environment/fuzzy rims,
multi-light fixtures, depth fog, layered soft shadows, continuous spring
cables, and persistent separated fracture sectors.
Rebuild with `./build.sh`, validate with `bun test.mjs`, then synchronize the
hub route `/core/bend-a-beet` with `bendjogos_web/sync_core.mjs`.
The Engine-integrated generated `c5d69a1` browser artifact has SHA-256
`f4048298d98d5f2822f8107d0eb807ba8d6977ef9a77c80c7246b21d9f5f197a`.

`Bend2 Core/demos/Bend Engine/` is the reusable pure library package. Model3D
provides 104 vertices, 192 triangle facets, UVs/normals, four procedural texture
families, reflection/fuzz and 104 anchored fur strands. Light and ray tracing
provide four light kinds, shadow-query/resolution cooperation, fog, sphere/
plane/triangle hits and Möller–Trumbore triangles. Physics provides Q10 force,
torque, contacts, six joint kinds, recursive articulations, pinned bodies and
iterative ragdoll histories. AI provides perception, memory, goals, inspectable
utility, legality-carrying decisions, deterministic plans, squads/worlds and
histories. Fluids adds Q10 particles/waves, buoyancy and drag samples, surface
forcing, refraction, Fresnel, absorption, and caustic controls. The shared
WebGL2 layer accepts arbitrary indexed custom meshes, provides 29 built-in
complex mesh families and animated character/bird/fish/whale/tree/coral/cloud
assemblies, and adds procedural materials, soft/wind/twist vertex motion,
correct normal transforms, transparent sorting, water/glass, caustics, fog,
and selectable cameras.

Its rendering audit contains 4 semantic headline claims, 3 structural Claim
helpers, 14 reusable universal library theorems and 5 closed certificates.
Physics contains 12 universal theorems/claims and 3 certificates. AI contains 8
semantic claim families, 5 helpers and 3 certificates. Fluids adds 8 universal
theorem families. The combined harness pins `c5d69a1`, rejects the removed
`#[halts]` spelling and requires `True{}` from generated JavaScript and native
C for all four focused entries. No genuine Bend issue was found, so the
package intentionally has no
`unexpected_behavior/` directory.

The Engine-backed Core games are `bendio_3d_land` (612 autonomous frames,
18 platforms, 5 theorem families/4 certificates), `bendy_birds` (6 bird and 7
block materials, live Core shot recomputation, 10/4), `bend_fishing` (one or
two occult fish, 120 water frames, five reel outcomes, 8/5), `bend_aquarium`
(12 fish, 12 corals, unbounded frame queries, 8/5), and `bend_landscape`
(unbounded keyed chunks, 12/6). Their browser cameras and timing selectors
choose presentation or a Core-computed branch. All five viewers now use
custom/compound geometry for terrain, creatures, plants, structures, props and
effects instead of relying on scaled primitive solids. Bendy Birds'
`recalculate.mjs` remains an explicit command-line recompilation bridge.

## 2026-08-18 current-worktree additions

The sibling `../bend3` worktree used for Farmhands has a newer CLI layout than
the detached 2026-08-17 audit: invoke it with `bun bend-ts/src/main.ts`. Check
the checkout being used instead of carrying this command across revisions.

`Bend3/demos/farmhands_web/` is a Bend3 LAN farming service with a 2 × 6 grid,
four initially unlocked plots, short test crops, persistent CSV credentials and
farm state, PBKDF2 password hashes, and the Colheita Feliz-style theft rules.
The owner retains at least 25%; a visitor can steal once per planting, each
planting accepts at most three thefts, and a visitor can steal at most two crops
per owner per day. Its pure rules contain 12 checked proofs. Server integration
tests cover registration, restart persistence, growth timing, harvest and all
theft limits. No compiler/runtime issue was found, so there is intentionally no
`unexpected_behavior` directory for this package.

Check a port and verify its JS backend from `../bend2-core`:

```sh
bun bend2/comp.ts "../Bend-Programs/Bend2 Core/programs/tree_sort.bend"
bun bend2/comp.ts "../Bend-Programs/Bend2 Core/programs/tree_sort.bend" --to /tmp/tree_sort.js
bun /tmp/tree_sort.js
```

Computational ports print `True{}` from `IO<Unit>` wrappers in both generated JS
and C. `nat_proofs` keeps its equality proof in `main_value` and prints `-`
after checking it; both backends accept the IO entry. The former licensed
programs now pass the mandatory termination checker: `integer_sqrt` reuses the
actual Nat predecessor, `merge_sort` carries combined-length fuel, and
`tournament` gives both child calls the actual reusable predecessor.

The C/JS compilers erase proofs and recognize canonical Base operations by
name. That intrinsification is why U32-heavy programs can normalize slowly but
run immediately after lowering. Both backends and the interpreter now execute
the same `IO<T>` protocol; compiled programs reject a non-IO `main`.

## CHIP-8 emulator

`Bend2 Core/programs/chip8/` is a new pure emulator, not a Bend-to-CHIP-8
compiler. It implements the classic COSMAC VIP instruction set over a 4 KiB
RAM array, 16 registers, 12-entry checked stack, 64×32 XOR framebuffer, keys,
timers, deterministic xorshift random state, and explicit Running/Waiting/
Releasing/Halted status. `0NNN` host-machine calls are reported unsupported; SUPER-CHIP
and XO-CHIP are out of scope.

Because Core has no argv or interactive keyboard input, `rom.bend` exports a
whitespace-separated hex String which is parsed and loaded at `0x200`. The
README has a required note to remove this embedded-ROM bridge when an argument/
input seam exists. `machine_key` is the future input seam. The bundled ROM
checks arithmetic/carry, BCD, call/return, original
shift behavior, random masking, font lookup/drawing, timer behavior, key skip,
PC/I, stack, and framebuffer. The implementation is structurally terminating.

The emulator returned `True{}` through the interpreter, generated JS, and a
clang-built native C executable. Re-run from `../bend2-core`:

```sh
bun bend2/comp.ts "../Bend-Programs/Bend2 Core/programs/chip8/chip8.bend"
bun bend2/comp.ts "../Bend-Programs/Bend2 Core/programs/chip8/chip8.bend" --to /tmp/chip8.c
clang -O2 -DBEND_PARALLEL=0 -DBEND_GPU=0 /tmp/chip8.c -o /tmp/chip8 && /tmp/chip8
```

## Editing discipline

- Keep `unexpected_behavior/` logs strictly about behavior attributable to the
  Bend parser, checker, compiler, Base/runtime, backend, or documented language
  modes. Do not record macOS/Metal/Chromium sandbox incidents, browser policy,
  firewall/LAN/port/process problems, network timing, test-harness state leaks,
  ordinary application bugs, UX gaps, or demo security/feature limitations as
  Bend issues. Consistent language constraints—such as significant declaration
  order or requiring a body-level `match` to head a definition—are not bugs and
  must not be logged merely because they are restrictive or surprising.
  Operational instructions may remain in ordinary READMEs when users need them
  to run a program.
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
