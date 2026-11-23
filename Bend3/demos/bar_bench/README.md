# bar_bench

The bar-bending bench, in a terminal (`bend_bar.bend`) and in a window
(`window_bar.bend`). Both share the physics and the animation state
machine in `Bench.bend`.

Ported to Bend 2.0.40 (and rechecked with the bendlang/bend source at
6b806192) on 2026-11-23: every file prints ALL PROOFS CHECK, with no
`@unsafe`. Commands below run from the repository root; build outputs go to
`/tmp`.

## bend_bar — the bar-bending bench

```
bend Bend3/demos/bar_bench/bend_bar.bend -o /tmp/bend_bar
/tmp/bend_bar                     # an ANSI terminal; input is read by line
printf '1\n4\n3\n4\nq\n' | /tmp/bend_bar > /tmp/frames.txt   # scripted
```

Keys (then Enter): `1` steel, `2` rubber, `3` carbon fiber, `4`/`b` (or an
empty line) bends the selected bar, `q` quits. Each bend loads a fresh
specimen. Input is read from `/dev/stdin` line by line (Base has no raw
keyboard read), as the old `IO.read_line` did.

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
bend Bend3/demos/bar_bench/window_bar.bend -o /tmp/window_bar
/tmp/window_bar +RTS --gpu off -RTS          # keys go to the window: 1 2 3, 4/b/space/enter bends, q quits
/tmp/window_bar --demo +RTS --gpu off -RTS   # unattended: steel, rubber, carbon, exit (~27 s)
/tmp/window_bar --probe                      # headless: no window, no display needed
```

The window is Base's `App.run` model: the state is `Bar{sel, phase, demo,
paced, last}`, `view` renders the current `Bench.Phase` and `tick` reads the
frame's events and advances the bench one 33 ms frame when the wall clock
says so (the old demo slept 33 ms per frame). The pure side still emits the
demos' flat `List<U32>` draw-command stream (clear / rect / 3x5 digit, y
biased by +1000); [`../CommandGFX.bend`](../CommandGFX.bend) parses it into
rectangles and builds the frame's `Image` quadtree top-down (a square is one
`Pix` as soon as its topmost rectangle covers it), about 3-4k leaves per
640x400 frame, and decodes `Key`/`Close` events back to the old key codes.
`effs/window.c` is the historical Cocoa effect, kept as a record, not used.

`--probe` prints, per material, what the table above promises, measured on
the state machine frame by frame (steel: peak force 1000.0 N, first yielding
frame at 4.5 cm [the 4.17 cm threshold falls between frames], rest 23.75 cm,
springback 6.25 cm, 16.3 Hz model / 16.9 Hz from zero crossings; rubber:
1.2 N, overshoot to -18.6 cm, back to -0.1 cm, 0.7 Hz; carbon: snaps at
26.7 cm), checks pixels of rendered frames (bar row, 30 cm tip deflection =
84 px, load arrow, red snap flash, fracture mark, fallen bar), and drives the
real `tick` through `App.play` with scripted key events.

On this CUDA machine run the window builds with `+RTS --gpu off -RTS`:
`App.run` frees every frame with `Image.drop!`, which puts the program on the
GPU and makes each frame 5-10x slower (see
`bugs/app-run-cuda-default-3x-slower`).

## Bend issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
