# bar_bench_web — the bar-bending bench as a webapp

```
# from the repository root
bend Bend3/demos/bar_bench_web/web_bar.bend -o Bend3/demos/bar_bench_web/build/web_bar
Bend3/demos/bar_bench_web/build/web_bar      # serves 0.0.0.0:8080
# on this machine: http://localhost:8080
# on the LAN:      http://<server-lan-ip>:8080
```

Run it from the repository root: the page is read from
`Bend3/demos/bar_bench_web/index.html` at request time. `build/` is
gitignored.

A Bend webapp is a Bend **HTTP server** (`../HTTP.bend` over Base's TCP).
This server holds all the physics of [../bar_bench](../bar_bench/)
(Euler–Bernoulli cantilever, real material data, plastic hinge, modal
release, brittle snap) — it imports the same `../bar_bench/Bench.bend` state
machine as the terminal and window front-ends — and the browser page is a
dumb canvas rasterizer interpreting the draw-command stream that
`../CommandGFX.bend` renders natively. The material buttons and **Bend!**
are real HTML buttons.

Routes (each also under `/bar`, which the page itself uses):

- `GET /` — the page
- `GET /frame/<mat>/<i>` — frame `i` for material 1 steel / 2 rubber /
  3 carbon, as `{"done":d,"st":"...","cmds":[...]}`
- anything else: 404; a non-GET: 405

The endpoint is **stateless**: frame `i` is `Bench.step` applied `i` times to
a fresh specimen (`i` is clamped to 400; a bend takes 92-288 frames), so any
frame is computable on demand, in any order. Verified with curl and a
client that walked every frame until `done`: steel 247 frames (46 push + 200
ring + the final pose), rubber 287, carbon 91 (snap at frame 41), 2-3 ms per
frame.

## Hub interface

`web_bar.bend` exposes, for `import ../bar_bench_web/web_bar.bend as Bar`:

- `Bar.Bar` — the state type (a request counter: the demo is stateless);
  `Bar.init() -> Bar.Bar`
- `Bar.route(req: HTTP.Request, s: Bar.Bar) -> IO(Bar.Bar & HTTP.Response)` —
  accepts the path with or without the leading `/bar`, so the hub can pass
  `/bar/...` requests unchanged (or stripped).
- `Bar.frame_at(mat, i) -> String` — the frame JSON.

`main` is only `HTTP.serve(~Bar, ~route, "0.0.0.0", 8080, init())`.

## Bend issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
