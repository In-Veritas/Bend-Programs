# gabriel_demos

Interactive Bend3 demos. Everything here runs as a **compiled native
binary** — the interpreter deliberately performs no IO (it prints the
pending effect tree instead), so build with `-o`.

Verified against upstream Bend3 `1ebc1acc` on 2026-08-17; that revision
contains the earlier `io_main` fix.

## bend_bar — the bar-bending bench

```
bun bend-ts/src/bend.ts gabriel_demos/bar_bench/bend_bar.bend --no-halt -o gabriel_demos/bar_bench/bend_bar
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
bun bend-ts/src/bend.ts gabriel_demos/bar_bench/window_bar.bend --no-halt -o gabriel_demos/bar_bench/window_bar
./gabriel_demos/bar_bench/window_bar           # keys go to the window: 1 2 3, 4/space/enter bends, q quits
./gabriel_demos/bar_bench/window_bar --demo    # unattended: steel, rubber, carbon, exit
```

Current Bend3's install `IO.Op` is fixed: a user C-bodied effect must have a
matching installed constructor. The old `win_open`/`win_frame`/`win_close`
effect therefore no longer compiles. `CommandGFX.bend` preserves the demo's
pure flat command stream while adapting it to the standard `IO/GFX` module:

- `win_open(w, h, title) -> IO(U32)` opens the standard GFX window;
- `win_frame(cmds: List(U32)) -> IO(U32)` rasterizes a flat command
  stream (clear / rect / 3×5 digit; y carries a +1000 bias so the pure
  side never builds a negative), present, pump events, return the key
  pressed (0 none, `'q'` if the window was closed)
- `win_close() -> IO(U32)` lets process teardown close the window.

The adapter builds a depth-9 quadtree image (2×2 display pixels) and maps the
standard key/close events back to the demo's U32 controls. The old
`effs/window.c` remains as historical source but is not imported. Both native
window binaries built and stayed live through bounded launch/render smoke
tests on the verification Mac.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
