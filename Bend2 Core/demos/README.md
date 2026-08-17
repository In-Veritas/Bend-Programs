# Bend3 demo port status

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

Both `.bend` programs are pure, affine Core programs with no hidden IO. Their
build scripts compile the reports to JavaScript; BendJogos only serves and
draws those generated values on its `/core` pages.

The remaining packages would require either new observer designs or a real Core
application boundary. They are deliberately not presented as working ports.
