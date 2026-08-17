# Duck Hunt

Duck Hunt is a Bend3-backed light-gun game for BendJogos. Its entire visual
presentation is drawn as original pixel art at a low logical resolution. It
does not load image, font, or audio assets.

The browser provides:

- mouse, keyboard, and touch aiming;
- pixel-art scenery, dog, duck variants, hit falls, escapes, and round cards;
- synthesized WebAudio shots, wings, barks, hits, jingles, and game-over cues;
- a responsive cabinet layout with a dedicated mobile fire control.

Bend3 owns shells, score, accuracy bonuses, ten-duck round progress, qualifying
hit counts, personal bests, and the shared LAN high score. Browser animation
does not independently award points.

## Run

Build and run the standalone service:

```sh
./gabriel_demos/duck_hunt_web/build.sh
./gabriel_demos/duck_hunt_web/start.sh
```

Then open `http://<server-lan-ip>:8089`.

The unified BendJogos build serves the same game at `/duck-hunt` on port 8090.

Browsers require a user gesture before WebAudio may play. Pressing **Start
hunt** unlocks audio; the sound switch also provides an explicit unlock path.

See [`unexpected_behavior/README.md`](unexpected_behavior/README.md) for the
exact Bend3 revisions, minimal reproductions, workarounds, browser constraints,
and remaining trust boundaries.
