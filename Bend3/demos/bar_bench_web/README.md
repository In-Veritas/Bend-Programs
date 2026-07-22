# bar_bench_web — the bar-bending bench as a webapp

```
node bend-ts/src/main.ts gabriel_demos/bar_bench_web/web_bar.bend --no-halt -o gabriel_demos/bar_bench_web/web_bar
./gabriel_demos/bar_bench_web/web_bar     # run from the repo root
# on this machine: http://localhost:8080
# on the LAN:      http://<server-lan-ip>:8080
```

The server listens on every IPv4 interface. Any machine on the same local
network can use the LAN URL as long as the host firewall allows port 8080.

Bend3 has no browser compile target — a Bend webapp is a Bend **HTTP
server**: `base/HTTP`'s `Router` (`Request -> IO<Response>`) served
keep-alive over the TCP effect. This server holds all the physics of
[../bar_bench](../bar_bench/) (Euler–Bernoulli cantilever, real
material data, plastic hinge, modal release, brittle snap) and the
browser page is a dumb canvas rasterizer — the web twin of
`effs/window.c`, interpreting the identical draw-command stream. The
material buttons and **Bend!** are real HTML buttons.

Routes:

- `GET /` — the page (`index.html`, read from disk at request time, so
  run the server from the repo root)
- `GET /frame/<mat>/<i>` — frame `i` for material 1 steel / 2 rubber /
  3 carbon, as `{"done":d,"st":"...","cmds":[...]}`

The endpoint is **stateless**: the whole animation is a pure function
`frame_at(mat, i)` — push frames come from the smoothstep ramp, ring
frames replay `i−46` steps of the modal oscillator (≤ 960 substeps of
arithmetic), the carbon snap index is found by scanning the ramp
against the fracture deflection. Any frame is computable on demand, in
any order, with no session state on the server.

Caveats: the accept loop is sequential (one connection served at a
time — fine for a local page whose JS fetches frames one by one), and
the JSON is hand-rolled since the numbers all come out of `List<U32>`
walks anyway.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
