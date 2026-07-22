# gabriel_demos

Interactive Bend3 demos. Everything here runs as a **compiled native
binary** — the interpreter deliberately performs no IO (it prints the
pending effect tree instead), so build with `-o`.

> **Requires the `io_main` fix.** As of upstream `81fd6dc` the compiled
> IO event loop never engages: the checker rebuilds application heads as
> `Ann(x, T)` and `io_main` (bend-ts/src/prep.ts) misses the `IO::IO`
> ref behind the wrapper, so every IO main dies with
> `error: main: expected a word`. This checkout carries a local patch in
> `bend-ts/src/prep.ts` that unwraps `Ann` before the identity test.

## bend_bar — the bar-bending bench

```
node bend-ts/src/main.ts gabriel_demos/bar_bench/bend_bar.bend --no-halt -o gabriel_demos/bar_bench/bend_bar
./gabriel_demos/bar_bench/bend_bar     # needs a real terminal (ANSI + line input)
```

Keys: `1` steel, `2` rubber, `3` carbon fiber, `4` (or Enter) bends the
selected bar, `q` quits. Each bend loads a fresh specimen.

A displacement-controlled cantilever bend test, the way a real bench
does it: the crosshead imposes tip deflection (0 → 30 cm, smoothstep),
the material answers with force. One bar: L = 1 m, 40×20 mm rectangle,
I = bh³/12 = 2.667e-8 m⁴. Deflection curve is the Euler–Bernoulli
tip-load shape y(x) = δ(3ξ²−ξ³)/2; force F = 3EIδ/L³; root fiber strain
ε = 3δc/L². Release dynamics is the first cantilever mode
ω₁ = 3.5160·√(EI/ρA)/L² (√ by Newton iteration), integrated as the
damped oscillator q̈ = −ω²(q−rest) − 2ζωq̇ with semi-implicit Euler,
4 substeps per frame. Steel/carbon vibrate at 16–30 Hz, so their
release plays in slow motion (factor in the HUD).

| material | data | what you see |
|---|---|---|
| Steel, AISI 1020 | E=200 GPa, σy=250 MPa, ρ=7850, ζ=0.2%, 120 HB | yields at δ=4.2 cm; force plateaus at the plastic-hinge cap F=1000 N; on release springs back only the elastic 6.2 cm, keeps a 23.75 cm permanent set, rings at 16.3 Hz |
| Rubber, vulcanized NR (~60 Shore A) | E=0.05 GPa, elastic to >500%, ρ=1100, ζ=15% | bends with ~1 N, recovers completely, wobbles at 0.7 Hz in real time with visible overshoot |
| Carbon fiber, UD CFRP 0° | E=135 GPa, εu≈0.8% (compressive), ρ=1600, ζ=0.5% | no yield: at δ=26.7 cm (σ≈1.08 GPa) it snaps at the root — the freed bar straightens as its elastic energy releases and falls |

Simplifications, on purpose: the elastic–plastic knee is `min(F, F_p)`
(the real curve rounds it), release vibration reuses the static curve as
the mode shape (Rayleigh's trick), and post-yield HUD strain/stress
gauges read `--` because the root state is residual, not the elastic
formula.

## window_bar — the same bench, in a real OS window

```
node bend-ts/src/main.ts gabriel_demos/bar_bench/window_bar.bend --no-halt -o gabriel_demos/bar_bench/window_bar
./gabriel_demos/bar_bench/window_bar           # keys go to the window: 1 2 3, 4/space/enter bends, q quits
./gabriel_demos/bar_bench/window_bar --demo    # unattended: steel, rubber, carbon, exit
```

The GPU does not create windows — on every platform the OS window
server does, and the GPU only fills surfaces the window system hands
it. Bend3's Metal/CUDA backend allocates headless *compute* contexts;
its one sanctioned door to the OS is the C-bodied IO effect protocol.
So the window comes from a custom effect, `effs/window.c` (~250 lines
of dependency-free C: Cocoa through `objc_msgSend`, CoreGraphics for
the canvas), exposing three ops:

- `win_open(w, h, title) -> IO<U32>`
- `win_frame(cmds: List<U32>) -> IO<U32>` — rasterize a flat command
  stream (clear / rect / 3×5 digit; y carries a +1000 bias so the pure
  side never builds a negative), present, pump events, return the key
  pressed (0 none, `'q'` if the window was closed)
- `win_close() -> IO<U32>`

The division of labor is the language's own: the pure fragment computes
every frame's F32 physics and geometry and emits draw commands; the
effect only blits them. Debug: `BEND_WIN_DUMP=<prefix>` writes every
40th frame as `<prefix>NNNN.ppm` so the canvas can be verified without
screen-capture permissions. The effect file compiles both as ObjC+ARC
(the Metal recipe's `-x objective-c -fobjc-arc`) and as plain C (the
CPU recipe) — hence the `WIN_ID` bridge macro and the runtime-built
run-loop-mode string.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
