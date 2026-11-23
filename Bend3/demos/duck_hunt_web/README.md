# Duck Hunt

Duck Hunt is a Bend3-backed light-gun game for BendJogos. Its entire visual
presentation is drawn as original pixel art at a low logical resolution. It
does not load image, font, or audio assets.

The browser provides:

- mouse, keyboard, and touch aiming;
- pixel-art scenery, dog, duck variants, hit falls, escapes, and round cards;
- synthesized WebAudio shots, wings, barks, hits, jingles, and game-over cues;
- a responsive cabinet layout with a dedicated mobile fire control.

Bend owns shells, score, accuracy bonuses, ten-duck round progress, qualifying
hit counts, personal bests, and the shared LAN high score. Browser animation
does not independently award points.

## Run

Build (Bend 2.0.40, current `bend` CLI, output in the gitignored `build/`) and
run the standalone service; both scripts `cd` to the repository root, which the
page path is relative to:

```sh
./Bend3/demos/duck_hunt_web/build.sh   # bend Bend3/demos/duck_hunt_web/web_duck_hunt.bend -o Bend3/demos/duck_hunt_web/build/web_duck_hunt
./Bend3/demos/duck_hunt_web/start.sh
```

Then open `http://<server-lan-ip>:8089`.

The unified BendJogos build serves the same game at `/duck-hunt` on port 8090.

## Hub interface

`web_duck_hunt.bend` exposes, for `import ../duck_hunt_web/web_duck_hunt.bend as Duck`:
`Duck.Game`, `Duck.init() -> Duck.Game`, and
`Duck.route(req, game) -> IO(Duck.Game & HTTP.Response)`, which accepts paths
with or without the leading `/duck-hunt` (the page picks its base from
`location.pathname`). `main` is a thin `HTTP.serve(~Game, ~route, "0.0.0.0", 8089, init())`.

Browsers require a user gesture before WebAudio may play. Pressing **Start
hunt** unlocks audio; the sound switch also provides an explicit unlock path.

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md) for the
exact Bend revisions, minimal reproductions, workarounds, browser constraints,
and remaining trust boundaries.
