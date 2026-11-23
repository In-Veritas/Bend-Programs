# Bend3 demo port status

> Toolchain note (2026-11): the old bend2-core compiler is gone. The two
> observer packages below were ported to the released **Bend 2.0.40** `bend`
> CLI. The table of blocked packages is the historical Bend2 Core assessment;
> Bend 2.0.40 itself has IO (files, TCP/HTTP, clock, windows), so those
> blockers no longer describe the current language, but no new interactive
> ports have been attempted here.

No complete *interactive* demo has a runnable Bend2 Core port. This is an
expected runtime boundary, not an unchecked assumption: Core's Base declares
only an effect-tree shape and has no implemented print/filesystem/clock/network
or window effects. It also lacks Bend3's F32, HTTP, TCP, JSON, Bytes, and rich
String libraries. The original verified packages remain in `Bend3/demos/`.

| Bend3 package | Blocking Core facilities |
|---|---|
| `Clock.bend` | custom C-bodied monotonic-clock effect |
| `bar_bench` | terminal/window IO, custom Cocoa effect, F32 |
| `elements` | custom Cocoa effect and F32 scene math |
| `bar_bench_web`, `elements_web` | filesystem, TCP/HTTP, F32 |
| `tictactoe_web` | filesystem and stateful TCP/HTTP server loop |
| `slither_web`, `agar_web` | clock plus TCP/HTTP server loop |
| `minecraft_web`, `cubeworld2_web` | clock, filesystem, TCP/HTTP |
| `club_corvid_web` | clock, JSON/Bytes, filesystem, TCP/HTTP |
| `duck_hunt_web` | filesystem and TCP/HTTP |
| `bend_obfuscator_web` | filesystem and TCP/HTTP; transformation itself is browser JS |
| `bendjogos_web` and `social.bend` | all server effects above plus custom password/LAN effects |

Two observer-style ports deliberately stay inside that boundary:

| Core package | What the Bend program computes | Browser responsibility |
|---|---|---|
| [`poker/`](poker/) | Four-AI Texas and Omaha timelines, cards, actions, stacks, best hands, and per-player win/category odds | Select a variant and advance or autoplay the immutable report |
| [`belote/`](belote/) | A seeded four-AI deal, bidding, 32 rules-checked plays, tricks, points, and contract result | Advance or autoplay the immutable report |

Both `.bend` programs are pure, affine Bend 2.0.40 programs with no IO and no
`@unsafe` (`bend X.bend --check-only` prints ALL PROOFS CHECK). Their
`build.sh` scripts run `bend X.bend -o X.mjs` and wrap that ES module into the
classic browser script `X_data.js` (globals `BEND2_POKER_DATA` /
`BEND2_BELOTE_DATA`; values use Bend's `{$: "Name", field: value}` export
encoding). BendJogos only serves and draws those generated values on its
`/core` pages.

| Generated asset | SHA-256 (Bend 2.0.40) |
|---|---|
| `poker/poker_data.js` | `88abe95ed69e0a36b0ae487fda1e2a8ebff49df1846c92dc5ae8e5dfe8e92886` |
| `belote/belote_data.js` | `958cd753dfd9d202377ed017365c0d37e6addce9649d922bec1afbcbb5fe77d5` |

Each build takes about 0.4 s. The reports are value-identical to the earlier
Bend2 Core artifacts (same deals, actions, odds, tricks and scores; only the
JS encoding changed). Rebuild and verify from each package directory with
`./build.sh && bun test.mjs`.

The remaining packages would require either new observer designs or a real Core
application boundary. They are deliberately not presented as working ports.
