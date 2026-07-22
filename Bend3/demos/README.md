# gabriel_demos

Interactive Bend3 demos. **One folder per demo** — each is self-contained
(its `.bend` sources, any C-bodied effects under `effs/`, its own README,
an `unexpected_behavior/` issue log, and the built binaries). The per-folder
layout lets new demos drop in beside the existing ones.

Everything here runs as a **compiled native binary** — the interpreter
deliberately performs no IO (it prints the pending effect tree instead),
so build with `-o`.

> **Requires the `io_main` fix.** As of upstream `81fd6dc` the compiled
> IO event loop never engages: the checker rebuilds application heads as
> `Ann(x, T)` and `io_main` (bend-ts/src/prep.ts) misses the `IO::IO`
> ref behind the wrapper, so every IO main dies with
> `error: main: expected a word`. This checkout carries a local patch in
> `bend-ts/src/prep.ts` that unwraps `Ann` before the identity test.

## Opening web apps from another machine

`TCP::listen` binds Bend servers to every IPv4 interface, not just loopback.
Start a web demo on the server, find that machine's LAN address, and open
`http://<server-lan-ip>:<port>` from any machine on the same network. For
example, a server at `192.168.1.40` exposes the apps below at ports
`8080`–`8084` and the BendJogos hub at `8090`. `localhost` only names the
machine running the browser. The server firewall must allow incoming traffic
to the selected binary/port.

## Demos

- **[bar_bench/](bar_bench/)** — a cantilever bar-bending bench (steel,
  rubber, carbon fiber) with real material data and Euler–Bernoulli
  physics. Two front-ends: `bend_bar` (ANSI terminal) and `window_bar`
  (a real Cocoa window via a custom IO effect). See its README.
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
- **[bendjogos_web/](bendjogos_web/)** — the BendJogos.com.br hub. It links all
  browser demos and also serves the standalone Balloon Defense and Helicopter
  games. `http://<server-lan-ip>:8090`.

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
- [BendJogos hub issues](bendjogos_web/unexpected_behavior/README.md)
