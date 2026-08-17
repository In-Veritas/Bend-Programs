# CubeWorld 2: isolated Bend3 behavior

## Summary

The normal checker reports `u32_serve` as unbound when the HTTP continuation
calls the server loop declared later in the same file. The identical source
checks and compiles with `--no-halt`, which enables whole-book checking for
this mutually recursive server shape. No Bend3 compiler or runtime source was
changed while developing the demo.

## Reproduction identity

- Bend npm package version: `0.1.0`
- Compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- CubeWorld 2 feature baseline: `9cce1a25fcda08e1857e53140fdeb77a17564e9d`
- Gameplay quality baseline: `7f3c0fc8593e3d5f689f08ac6bfcd8f29c47e341`
- Observed: 2026-07-22
- Quality review recorded: 2026-07-27

The feature baseline contains the exact demo and compiler used for the
observation. The compiler/base revision is the most recent commit touching
`bend-ts/src` or `base` in that checkout.

## Reproduction

From the repository root at the feature baseline:

```sh
git checkout 9cce1a25fcda08e1857e53140fdeb77a17564e9d
node bend-ts/src/main.ts gabriel_demos/cubeworld2_web/web_cubeworld2.bend
```

The production source reports `u32_serve` as unbound from `routed_send`. This
is preserved as a reproducible observation, not treated as proof that forward
declarations are intended to work in the default checking mode.

The same distinction has one canonical isolated reproduction in
[`mre_mutual_scope.bend`](../../minecraft_web/unexpected_behavior/mre_mutual_scope.bend):

```text
NotBound:
- name : u32_second
```

## Demo-side workaround

The build uses the existing whole-book option:

```sh
node bend-ts/src/main.ts gabriel_demos/cubeworld2_web/web_cubeworld2.bend --no-halt
```

No compiler modification is part of the workaround. To reproduce the
behavior, use the versions above and run the failing command before applying
any compiler change.

## Issue: joining could not reliably capture the mouse

### Summary

The original client requested pointer lock only after awaiting the network
join. Browsers may clear transient user activation across that asynchronous
boundary, so clicking **Join the world** could enter the game without enabling
mouse-look.

### Detailed explanation and reproduction

At `9cce1a25fcda08e1857e53140fdeb77a17564e9d`, `join()` awaited
`request("/join/...")` and then called `canvas.requestPointerLock()`. Check out
that revision, open the game in a desktop Chromium browser, and click Join.
On affected browser versions, `document.pointerLockElement` remains `null`.

This is browser activation behavior, not Bend3 behavior.

### Resolution

At `7f3c0fc8593e3d5f689f08ac6bfcd8f29c47e341`, joining and mouse
capture are separate, visible steps. Clicking the canvas directly requests
pointer lock while the click activation is still live. The HUD reports whether
the pointer is captured and explains that Escape releases it.

## Issue: attacks ignored the crosshair

### Summary

If no entity was under the crosshair, the old client selected the nearest
in-range mob or player. A player could look away, attack, and still damage an
enemy behind or beside the view.

### Detailed explanation and reproduction

At the original feature baseline, `attackOrMine()` fell back to
`entityTarget()`, which sorted every nearby entity only by Manhattan distance.
Join the world, allow a raider within two cells, aim at empty terrain, and use
Attack. The request still targets that raider.

### Resolution

The fallback was removed. Entity hit boxes and visible block-face polygons are
projected into screen space; only the nearest object containing the center
crosshair can be acted upon. The Bend backend continues to validate reach.

## Issue: the first-person controls had no pitch or held movement

### Summary

Mouse movement changed yaw only, and repeated keydown events were discarded.
The result looked first-person but could not aim up or down and moved only one
cell per physical keypress.

### Resolution

The browser camera now applies yaw and clamped vertical pitch before
projection. Movement keys are tracked while held, touch drag controls both
axes, the mouse wheel changes materials, and the selected block face receives
a visible outline.

## Issue: NPC speed depended on state-request count

### Summary

Every `/state` request unconditionally advanced all raiders and applied their
damage. More polling clients therefore increased simulation speed.

### Detailed explanation and reproduction

At `9cce1a25fcda08e1857e53140fdeb77a17564e9d`, `game_state()` always
called `game_advance()`, and `game_advance()` always moved every living mob.
Join a player near a raider and compare its movement while one client polls
with movement while several clients repeatedly request `/state`.

### Resolution

The `Game.tick` value now records the last authoritative NPC advance. Bend
permits one advance per 650 ms and preserves that timestamp across joins,
movement, world edits, and attacks. Request volume no longer directly counts
as simulation steps.

## Remaining demo limitations

- Terrain is represented as one vertical column per X/Z coordinate, not a
  general three-dimensional voxel array. Aiming at a visible side still mines
  or builds on that column's top stack.
- Reach is server-authoritative, but facing is not transmitted to Bend. A
  custom HTTP client can name any in-range target even though the supplied
  browser only sends the object under its crosshair.
- The four-player world and all edits remain in memory and reset on restart.

## Quality-baseline verification

At `7f3c0fc8593e3d5f689f08ac6bfcd8f29c47e341`:

- the CubeWorld source checks with the documented `--no-halt` mode;
- its native standalone binary builds and serves strict JSON;
- a headless Chromium interaction test joined, rendered without page errors,
  produced multiple move requests from one held key, changed the hotbar with
  the mouse wheel, and captured a gameplay screenshot; and
- the full Bend3 repository suite passed 506/506.
