# BendJogos.com.br

BendJogos.com.br is the LAN hub for the browser games and interactive demos in
`Bend3/demos/`.

The hub provides:

- Snake Arena — four-player LAN game under `/snake`
- Cell Arena — four-player LAN game under `/cells`
- Block World — four-player voxel sandbox under `/minecraft`
- CubeWorld 2 — first-person voxel survival, hostile NPCs, and PvP under
  `/cubeworld2`
- Poker — four-seat Texas Hold'em or Omaha with invitations, ten AI personas,
  betting, private views, and live odds under `/poker`
- Belote — classic solo French card table with Bend-controlled partner,
  opponents, rules, bidding, and scoring under `/belote`
- Club Corvid — multiplayer social world, room chat, room music, sound effects,
  and four bird minigames under
  `/club-corvid`
- Duck Hunt — Bend-scored pixel-art light-gun game with synthesized sound under
  `/duck-hunt`
- Balloon Defense — single-player browser game served by the hub
- Helicopter — single-player browser game served by the hub
- Tic-tac-toe — two-player LAN game under `/tic`
- Farmhands — persistent multiplayer farms (plant, harvest, visit and take a
  quarter of a ripe crop) with PBKDF2 accounts under `/farmhands`
- Bar Bench — server-computed Bend demo under `/bar`
- Elements — server-computed Bend demo under `/elements`
- Virome Clustering — full EarlyVir VClust preparation and an interactive
  180-run comparison of Bend-to-C, independent C11, and VClust/Clusty across
  five equivalent algorithms and 1/2/4/8 requested threads, plus preliminary
  full-FASTA timings for Bend's proven inverted MinHash path and the validated
  indexed Bend LZ-ANI/tANI port status, under `/clustering`
- Bend3 Source Obfuscator — private in-browser structural source transform with
  arithmetic constants, long misleading symbols, function splitting, and
  chaotic spacing under `/obfuscator`
- Social lounge — in-memory accounts, friend requests, presence, friend-only
  chat, and game invitations under `/social` and directly on the home page

Start the hub with one command (from any directory; it builds on first use):

```sh
/home/veritas/Bend-Programs/Bend3/demos/bendjogos_web/start.sh
# or, from the repository root:
./Bend3/demos/bendjogos_web/start.sh            # --rebuild forces a fresh build
```

It needs the `bend` command (Bend 2.0.40) on `PATH` and, for `sync_core.mjs`,
`bun` (optional: without it the checked-in `core/` assets are served).
`build.sh` refreshes `core/` with `sync_core.mjs`, checks
`web_bendjogos.bend` (ALL PROOFS CHECK) and compiles it to
`build/web_bendjogos` (gitignored). The native build is long: on the porting
machine it took 1 min 19 s wall time and peaked at about 15.7 GB of memory.
The process must run from the repository root, because every page path
(`Bend3/demos/<demo>/index.html`, `Bend3/demos/bendjogos_web/core/...`) is
relative to it; `start.sh` changes there itself.

Open `http://<server-lan-ip>:8090` on any desktop or mobile device connected to
the same local network. Every route and every game uses this one port; the
server listens on `0.0.0.0:8090`. Farmhands keeps its CSVs in
`Bend3/demos/farmhands_web/data/` (or `FARMHANDS_DATA_DIR`), shared with the
standalone Farmhands server.

### How the hub is composed (Bend 2.0.40)

`web_bendjogos.bend` imports every standalone demo source directly through a
module alias, for example `import ../tictactoe_web/web_tictactoe.bend as Tic`
or `import ../farmhands_web/web_farmhands.bend as Farm`, and uses the
interface each demo documents under "Hub interface" in its README (`Game`,
`init`, `route` / `route_at` / `route_now`). Each demo accepts its own prefix
(`/tic/...`, `/poker/...`), so the hub passes requests through unchanged;
Snake and Cells advance their simulation inside `route_now`. The social
lounge is `social.bend` (`Social.route(req, state, now)`).

The old Bend3 merged all imports into one global book, so the previous hub
compiled generated copies under `modules/` produced by `generate_modules.mjs`.
That folder is deleted and `generate_modules.mjs` is a no-op kept for old
scripts: the standalone sources are now the only copy.

The hub state `Platform` keeps each game behind a self-referential `Held`
box: with all fourteen states unboxed side by side, the native backend
refused the program with `an arity over 247` (see
`bugs/native-arity-over-247-wide-records`).

Tests: `bun Bend3/demos/bendjogos_web/test_client.mjs` checks the pages and
Core assets offline; the standalone HTTP clients accept the hub as their base
(for example `bun Bend3/demos/minecraft_web/test_server.mjs
http://127.0.0.1:8090/minecraft`, `POKER_URL=http://127.0.0.1:8090/poker bun
Bend3/demos/poker_web/test_server.mjs`).

## Bend3 / Bend2 Core runtime switch

The fixed runtime control opens `/core` on the same origin and port. The Bend3
native process remains the HTTP shell because Bend2 Core has no runnable IO,
TCP, or HTTP scheduler. Pages under `/core` are pure Core reports compiled to
JavaScript and rendered in the browser; the switch does not misrepresent them
as a second network server. Poker is available at `/core/poker` as a four-AI,
omniscient odds observer backed by three semantic chip-conservation theorems,
three deal lemmas and 78 closed
table certificates; Belote is available at `/core/belote` as a fully
visible hand backed by three semantic card-conservation theorems, one mapping
lemma and 119 finite
deal/play/scoring certificates. Bend-a-Beet is available at
`/core/bend-a-beet`
as a seeded 3D farm with 20 general theorems and 35 closed certificates,
including its Bend Engine material/light profile integration.
The same Core catalog now serves five larger Bend Engine simulations:

- `/core/bendio-3d-land` is a keyed 18-platform NPC course with 17 constrained
  jumps, 612 non-looping frames, five camera presentations, five general theorem
  families, and four certificates;
- `/core/bendy-birds` has six deformable bird materials, seven destructible
  target materials, persistent damage, exact angle/power/prior-state Core
  recomputation, ten
  theorem families, and four certificates;
- `/core/bend-fishing` maintains one or two occult fish from a weighted
  ten-species pool and accepts separate cast and reel clicks through pure Core
  functions; it has eight theorem families and five certificates;
- `/core/bend-aquarium` contains twelve distinct reef fish, twelve moving coral
  colonies across eight forms, an unbounded Core frame function, eight theorem
  families, and five certificates; and
- `/core/bend-landscape` retains a proof-carrying boundary between arbitrary
  keyed Sea/Land/Sky chunks and renders whales, schools, terrain, humans, birds,
  clouds, wind, rain, and tides; it has twelve structural/arithmetic theorem
  families and six certificates.

The new viewers share Bend Engine's WebGL2 renderer and the simulations share
its proven fixed-point physics, lighting, ray, AI, and fluid modules. Browser
camera/timeline controls are the browser presentation boundary; they are not
Core IO. Live choices are passed as arguments to generated pure Core functions,
so Bendy Birds, Fishing, Aquarium, and Landscape produce new Core-owned values
without recompiling source or moving their simulation rules into JavaScript.

The Core Poker and Belote packages were re-ported to Bend 2.0.40: their
generated `poker_data.js` / `belote_data.js` now use the named JS encoding
(`{$: "Name", field: value}`, Nat as a number, Bool as a boolean, plus a
`verification` field holding the audit) and their pages decode it. The other
Core assets keep the encoding they were checked in with until their packages
are re-ported; `sync_core.mjs` copies whatever each package currently builds.

Poker and Belote link directly back to their interactive Bend3 counterparts;
the six Engine-backed Core simulations (including Bend-a-Beet) are currently
Core-only.

`BendJogos.com.br` is the displayed site name. To use that exact hostname on a
LAN, configure local DNS or a hosts-file entry that maps it to the server's LAN
address; otherwise use the IP address directly.

`start.sh` starts one Bend process. The host firewall only needs to allow port
8090.

The social store is intentionally in memory for this LAN demo, so accounts,
sessions, friendships, messages, and invites disappear on restart. Online
presence expires after inactivity, and multiplayer game pages publish the
signed-in player's current activity. Passwords are reduced to a compact digest rather than
stored in clear text, but this is not a production password KDF or an HTTPS
deployment.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md) for the
versioned issue log, reproductions, resolutions, and current limitations.

The previous 2026-08-17 retest used upstream `1ebc1acc`; the current port
targets Bend 2.0.40 (latest bendlang/bend source, HEAD 6b806192). Rebuild size
and timing figures are intentionally recorded after every whole-suite compile
rather than treated as stable properties of the source.
