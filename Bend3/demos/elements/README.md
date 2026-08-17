# elements — the four bending arts

```
bun bend-ts/src/bend.ts gabriel_demos/elements/elements.bend --no-halt -o gabriel_demos/elements/elements
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
fragment computes each frame and emits a flat `List(U32)` of draw commands.
`CommandGFX.bend` rasterizes that stream into the standard Bend3 `GFX` image
tree and maps window input back to the old U32 controls. The historical
`effs/window.c` is retained for archaeology but is no longer imported because
current install `IO.Op` requires matching installed constructors. The `N` is
the honest 3×5-pixel compromise.

Against upstream `1ebc1acc`, the source checked, emitted C, built natively, and
remained live through a bounded launch/render smoke test.

## Bend3 issues and unexpected behavior

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md).
