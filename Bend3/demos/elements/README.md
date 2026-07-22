# elements — the four bending arts

```
node bend-ts/src/main.ts gabriel_demos/elements/elements.bend --no-halt -o gabriel_demos/elements/elements
./gabriel_demos/elements/elements          # runs until q or the window closes
./gabriel_demos/elements/elements --demo   # ~10 s unattended, then exits
```

A 640×400 Cocoa window titled **Bend!**, with "BEND!" rendered up top
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
fragment computes each frame and emits a flat `List<U32>` of draw
commands; `effs/window.c` (this demo's copy of the Cocoa effect, its
3×5 font extended with **B E N D !**) rasterizes and presents them.
`BEND_WIN_DUMP=<prefix>` dumps every 40th frame as a `.ppm` for
verification. The `N` is the honest 3×5-pixel compromise.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
