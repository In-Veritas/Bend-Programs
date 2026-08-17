# gabriel_demos

Interactive Bend3 demos. **One folder per demo** — each contains its `.bend`
sources, pages/assets, README, issue log, and optional build script. They use
the sibling `bend-base/` shipped by current Bend3.

Everything here runs as a **compiled native binary** — the interpreter
deliberately performs no IO (it prints the pending effect tree instead),
so build with `-o`.

The full set was migrated and verified against upstream Bend3
`1ebc1acc` on 2026-08-17. That upstream includes the earlier `io_main` fix.
Current Bend3 uses explicit file-relative imports, dot-qualified constructors,
parenthesized type application, a fixed install `IO.Op`, and `bun
bend-ts/src/bend.ts` as its CLI. Historical issue logs retain their original
revisions and commands; their current retest status is recorded separately.

## Opening web apps from another machine

`TCP.listen` binds Bend servers to every IPv4 interface, not just loopback.
Start a web demo on the server, find that machine's LAN address, and open
`http://<server-lan-ip>:<port>` from any machine on the same network. For
example, a server at `192.168.1.40` exposes the apps below at ports
`8080`–`8088` and the BendJogos hub at `8090`. `localhost` only names the
machine running the browser. The server firewall must allow incoming traffic
to the selected binary/port.

## Demos

- **[bar_bench/](bar_bench/)** — a cantilever bar-bending bench (steel,
  rubber, carbon fiber) with real material data and Euler–Bernoulli
  physics. Two front-ends: `bend_bar` (ANSI terminal) and `window_bar`
  (a real Cocoa window through Bend3's standard `GFX` effect). See its README.
- **[elements/](elements/)** — the four bending arts from Avatar in a
  2×2 window: earth pillars riding a bender's wave, water waves with a
  lifted whirling stream, layered flickering flames, and a spiral air
  vortex. "BEND!" on top; clicking applies element-specific force at the
  exact point under the pointer. See its README.
- **[bar_bench_web/](bar_bench_web/)** — the bar bench as a webapp:
  a Bend HTTP server (base/HTTP Router over the TCP effect) computes
  every frame server-side and serves it as draw commands; the page is
  a canvas rasterizer with real HTML buttons.
  `http://<server-lan-ip>:8080`.
- **[elements_web/](elements_web/)** — the elements as a webapp, same
  server-computes/browser-blits split. `http://<server-lan-ip>:8081`.
- **[tictactoe_web/](tictactoe_web/)** — two devices share a stateful Bend
  tic-tac-toe game. Players choose X or O and take turns over the LAN.
  `http://<server-lan-ip>:8082`.
- **[slither_web/](slither_web/)** — Snake Arena, an authoritative Bend server
  for up to four LAN players with food, growth, collisions, respawns, and
  desktop/mobile controls. `http://<server-lan-ip>:8083`.
- **[agar_web/](agar_web/)** — Cell Arena, an authoritative Bend server for up
  to four LAN players that collect food and absorb smaller players.
  `http://<server-lan-ip>:8084`.
- **[minecraft_web/](minecraft_web/)** — Block World, a compact multiplayer
  voxel sandbox with a procedural shared world, five materials, mining,
  building, and desktop/mobile controls. Standalone on
  `http://<server-lan-ip>:8085`, or through the one-port hub at `/minecraft`.
- **[cubeworld2_web/](cubeworld2_web/)** — CubeWorld 2, a first-person
  multiplayer voxel survival game with a 48×48 world, twelve materials,
  hostile NPCs, PvP, health, and respawning.
  Standalone on `http://<server-lan-ip>:8086`, or through the one-port hub at
  `/cubeworld2`.
- **[club_corvid_web/](club_corvid_web/)** — Club Corvid, a cozy multiplayer
  social world with four locations, room chat, chubby corvid avatars, four
  bird minigames, original procedural songs, and interaction sound effects.
  Standalone on `http://<server-lan-ip>:8087`, or through the one-port hub at
  `/club-corvid`.
- **[bend_obfuscator_web/](bend_obfuscator_web/)** — an aggressive private
  Bend3 source obfuscator with misleading and random long names, arithmetic
  constant expansion, function splitting, chaotic spacing, symbol mapping,
  copy, and download. Processing stays in the browser. Standalone on
  `http://<server-lan-ip>:8088`, or through the one-port hub at `/obfuscator`.
- **[poker_web/](poker_web/)** — a four-seat Texas Hold'em and Omaha room with
  browser-player invitations, ten Bend AI personalities, no-limit betting,
  private-card isolation, and visible-information odds. Standalone on
  `http://<server-lan-ip>:8092`, or through the one-port hub at `/poker`.
- **[belote_web/](belote_web/)** — classic French Belote for one human and
  three Bend-controlled seats. Bend owns the deal, bidding, legal-play rules,
  tricks, scoring, and match state. Standalone on
  `http://<server-lan-ip>:8091`, or through the one-port hub at `/belote`.
- **[bendjogos_web/](bendjogos_web/)** — the BendJogos.com.br hub. One native
  Bend process serves every browser demo and all shared multiplayer state on
  `http://<server-lan-ip>:8090`; a fixed runtime switch opens the Bend2 Core
  Poker and Belote observers on that same origin.

## Current verification

Against `1ebc1acc`, all sixteen entry programs typechecked, emitted C, and
built natively. The twelve standalone HTTP programs now include Poker on 8092.
The rebuilt BendJogos hub served Bend3 Poker and Belote plus both compiled-Core
observer pages on 8090. Automated clients completed an entire Texas hand and an
entire Belote hand through the hub; route, private-card, invitation, Core-data,
obfuscator, Club Corvid, Belote, Poker, and hub browser checks passed.

## Bend3 issue logs

Each package records the issues, limitations, and surprising behavior found
while building it. Every log includes the Bend3 package version and exact Git
revisions used:

- [Bar Bench issues](bar_bench/unexpected_behavior/README.md)
- [Elements issues](elements/unexpected_behavior/README.md)
- [Bar Bench Web issues](bar_bench_web/unexpected_behavior/README.md)
- [Elements Web issues](elements_web/unexpected_behavior/README.md)
- [Tic-tac-toe issues](tictactoe_web/unexpected_behavior/README.md)
- [Snake Arena issues](slither_web/unexpected_behavior/README.md)
- [Cell Arena issues](agar_web/unexpected_behavior/README.md)
- [Block World issues](minecraft_web/unexpected_behavior/README.md)
- [CubeWorld 2 issues](cubeworld2_web/unexpected_behavior/README.md)
- [Club Corvid issues](club_corvid_web/unexpected_behavior/README.md)
- [Bend3 Source Obfuscator issues](bend_obfuscator_web/unexpected_behavior/README.md)
- [Poker issues](poker_web/unexpected_behavior/README.md)
- [Belote issues](belote_web/unexpected_behavior/README.md)
- [BendJogos hub issues](bendjogos_web/unexpected_behavior/README.md)
