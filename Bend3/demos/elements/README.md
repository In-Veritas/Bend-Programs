# elements — the four bending arts

```
bend Bend3/demos/elements/elements.bend -o /tmp/elements
/tmp/elements +RTS --gpu off -RTS          # runs until q or the window closes
/tmp/elements --demo +RTS --gpu off -RTS   # ~10 s unattended, then exits
/tmp/elements --probe                      # headless: no window, no display needed
```

A 640×400 window titled **Bend!**, with "BEND!" rendered up top
and the four elements each being worked in its own clickable panel.
The exact click point supplies the origin, direction, and strength of that
element's short bending reaction:

| panel | element | motion |
|---|---|---|
| top-left | earth | sends an impact wave through the clicked ground and launches each boulder up and away from the epicenter |
| top-right | water | raises a ripple at the click and pulls the lifted stream toward it |
| bottom-left | fire | feeds a localized hotspot, so nearby columns and sparks react most |
| bottom-right | air | treats the center-to-click vector as a gust, moving and expanding the vortex in that direction |

Horizontal and vertical position both contribute to every reaction, so
clicking different parts of the same panel produces different motion.

Everything is sums of traveling sines. Bend has no trig primitives, so
`fsin` is Bhāskara I's 7th-century approximation (accurate to ~0.2%)
with floor-based range reduction — the floor comes from a +1024 shift
so U32 truncation acts as floor on negative phases, and the clock wraps
at 1000·2π so phases stay in range forever.

Rendering follows the same protocol as `bar_bench/window_bar`: the pure
fragment computes each frame and emits a flat `List<U32>` of draw commands
(the same stream `../elements_web` sends to the browser).
[`../CommandGFX.bend`](../CommandGFX.bend) turns it into the frame's `Image`
quadtree (about 12k leaves) and maps a main-button `Press` back to the old
packed panel click. The app is Base's `App.run`: the state is `El{t, e, w, f,
a, left, paced, last}`; a click starts its panel's reaction at once, and the
clock and the reaction countdowns advance once per 33 ms of wall clock, as
the old loop's `IO.sleep(33)` did. The historical `effs/window.c` is kept as
a record, not used. The `N` is the honest 3×5-pixel compromise.

Bend 2.0.40 has `F32.sin`; the scene keeps Bhāskara on purpose, and
`--probe` measures it against `F32.sin` (max error 0.0016 over [-20, 20]),
checks pixels of a calm and a struck frame (title glyph, the four panels'
idle and active colors, ground and pool), and drives the real `tick` with
scripted clicks and keys through `App.play` (each click lands in its panel
at the right local point and cools to 0 after its countdown; `q` quits).

Ported to Bend 2.0.40 (rechecked with the bendlang/bend source at 6b806192)
on 2026-11-23: ALL PROOFS CHECK, no `@unsafe`; the old `U32`-countdown loops
are `Nat`-fuel recursions and `if`-style `match`es on computed values became
Bool helpers. On this CUDA machine use `+RTS --gpu off -RTS`: `App.run`
frees each frame with `Image.drop!`, which makes frames 5-10x slower on the
GPU (`bugs/app-run-cuda-default-3x-slower`).

## Bend issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
