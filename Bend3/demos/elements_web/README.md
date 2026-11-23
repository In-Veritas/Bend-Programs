# elements_web — the four bending arts as a webapp

```
# from the repository root
bend Bend3/demos/elements_web/web_elements.bend -o Bend3/demos/elements_web/build/web_elements
Bend3/demos/elements_web/build/web_elements      # serves 0.0.0.0:8081
# on this machine: http://localhost:8081
# on the LAN:      http://<server-lan-ip>:8081
```

Run it from the repository root: the page is read from
`Bend3/demos/elements_web/index.html` at request time. `build/` is
gitignored.

The same interactive pure scene stack as [../elements](../elements/) —
imported from `../elements/elements.bend`, not copied — the exact click
position becomes Earth's impact point, Water's pull point, Fire's hotspot,
or Air's gust vector; but the presenter is a browser canvas instead of a
window. The Bend HTTP server computes any frame on demand; the page only
rasterizes the draw-command stream (including the 3×5 glyph font, ported to
~10 lines of JS).

Routes (each also under `/elements`, which the page itself uses):

- `GET /` — the page
- `GET /frame/<i>/<earth>/<water>/<fire>/<air>` — `{"cmds":[...]}` for
  frame `i`, with four packed reaction states supplied by the page; each
  state stores the remaining countdown and its panel-local x/y coordinate
- `GET /frame/<i>` — the same frame with every reaction inactive
- anything else: 404; a non-GET: 405

The server stays stateless: the page packs pointer coordinates with four
short countdowns, and the scene remains a pure function of time plus those
reaction states. `i` wraps at 190 400 (≈ 1000·2π seconds) so phases stay
inside `fsin`'s valid range no matter how long the page runs. Verified with
curl and a client: `/frame/10` equals `/elements/frame/10/0/0/0/0`, an earth
reaction lights its panel (2634274 instead of 1709839) and moves the scene,
about 6 ms per frame.

## Hub interface

`web_elements.bend` exposes, for
`import ../elements_web/web_elements.bend as Elements`:

- `Elements.Elements` — the state type (a request counter: the demo is
  stateless); `Elements.init() -> Elements.Elements`
- `Elements.route(req: HTTP.Request, s: Elements.Elements) ->
  IO(Elements.Elements & HTTP.Response)` — accepts the path with or without
  the leading `/elements`, so the hub can pass `/elements/...` requests
  unchanged (or stripped).
- `Elements.frame_json(i, earth, water, fire, air) -> String`.

`main` is only `HTTP.serve(~Elements, ~route, "0.0.0.0", 8081, init())`.

## Bend issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
