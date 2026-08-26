# BendJogos.com.br

BendJogos.com.br is the LAN hub for the browser games and interactive demos in
`gabriel_demos/`.

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
- Bar Bench — server-computed Bend demo under `/bar`
- Elements — server-computed Bend demo under `/elements`
- Bend3 Source Obfuscator — private in-browser structural source transform with
  arithmetic constants, long misleading symbols, function splitting, and
  chaotic spacing under `/obfuscator`
- Social lounge — in-memory accounts, friend requests, presence, friend-only
  chat, and game invitations under `/social` and directly on the home page

From the repository root, build every service once:

```sh
./gabriel_demos/bendjogos_web/build.sh
```

The build first runs `generate_modules.mjs`. Current Bend3 imports merge
declarations into one global book; import aliases do not provide language
namespaces. The generator therefore derives hub-private dotted declarations
under `modules/` from each independently compilable standalone demo. Generated
modules are checked in for review, but the standalone sources remain the source
of truth and the build refreshes them before compiling. It then runs
`sync_core.mjs`, which copies already-compiled Bend2 Core observer assets into
the hub without teaching Core nonexistent filesystem or HTTP effects.

Then start the full hub:

```sh
./gabriel_demos/bendjogos_web/start.sh
```

Open `http://<server-lan-ip>:8090` on any desktop or mobile device connected to
the same local network. Every route and every game uses this one port.

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

The previous 2026-08-17 retest used upstream `1ebc1acc`. Rebuild size and timing
figures are intentionally recorded after every whole-suite compile rather than
treated as stable properties of the source.
