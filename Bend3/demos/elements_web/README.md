# elements_web — the four bending arts as a webapp

```
bun bend-ts/src/bend.ts gabriel_demos/elements_web/web_elements.bend --no-halt -o gabriel_demos/elements_web/web_elements
./gabriel_demos/elements_web/web_elements     # run from the repo root
# on this machine: http://localhost:8081
# on the LAN:      http://<server-lan-ip>:8081
```

The server listens on every IPv4 interface. Any machine on the same local
network can use the LAN URL as long as the host firewall allows port 8081.

The same interactive pure scene stack as [../elements](../elements/) —
the exact click position becomes Earth's impact point, Water's pull point,
Fire's hotspot, or Air's gust vector — but the presenter is a browser
canvas instead of a Cocoa window. The
Bend HTTP server computes any frame on demand; the page only
rasterizes the draw-command stream (including the 3×5 glyph font,
ported to ~10 lines of JS).

Routes:

- `GET /` — the page (`index.html`, read from disk at request time, so
  run the server from the repo root)
- `GET /frame/<i>/<earth>/<water>/<fire>/<air>` — `{"cmds":[...]}` for
  frame `i`, with four packed reaction states supplied by the page; each
  state stores the remaining countdown and its panel-local x/y coordinate
- `GET /frame/<i>` — the same frame with every reaction inactive

The server stays stateless: the page packs pointer coordinates with four
short countdowns, and the scene remains a pure function of time plus those
reaction states. `i` wraps at 190 400 (≈ 1000·2π seconds) so phases stay
inside `fsin`'s valid range no matter how long the page runs.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
