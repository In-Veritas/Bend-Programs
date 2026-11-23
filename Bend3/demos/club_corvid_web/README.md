# Club Corvid

Club Corvid is an original, compact multiplayer social world written in
Bend (ported to Bend 2.0.40). Each visitor is a charming chubby corvid who can waddle around four
shared locations, see the flock, chat with everyone in the current room, and
play four arcade minigames. Each room has a themed catalog, interactive
sound-producing scenery, and its own small original song.

The browser handles drawing and input. Bend owns the authoritative player
list, room membership, positions, presence timeouts, room chat history, and
minigame scores and hidden state. It also owns every bird's coin balance,
catalog purchases, equipped item, and minigame payouts.

The browser synthesizes music and sound effects with Web Audio after the first
click or tap (required by browser autoplay rules). The header sound button
silences or restores all audio and remembers the choice. The four room themes,
four minigame songs, Rookery Rumba, and short effects are original note
sequences generated at runtime; there are no downloaded MIDI files, copyrighted
recordings, external assets, or CDN dependencies.

## Run it

Requires the `bend` 2.0.40 CLI on `PATH`. From the repository root:

```sh
bend Bend3/demos/club_corvid_web/web_club_corvid.bend --check-only   # ALL PROOFS CHECK
./Bend3/demos/club_corvid_web/build.sh   # bend ... -o Bend3/demos/club_corvid_web/build/web_club_corvid
./Bend3/demos/club_corvid_web/start.sh   # builds if needed, runs from the repository root
```

The server reads `Bend3/demos/club_corvid_web/index.html` relative to the
repository root, so always launch it from there (`start.sh` does).

Tests (bun): `bun Bend3/demos/club_corvid_web/test_client.mjs` checks the
browser client offline; with a freshly started server,
`bun Bend3/demos/club_corvid_web/test_server.mjs` plays the whole protocol
(join and name rules, movement and clamping, rooms, UTF-8 chat and its
24-message history, catalog buying/equipping, all four minigames, leaving, the
twelve-bird limit) and prints `/state` timings.

Open `http://localhost:8087`, or replace `localhost` with the server's LAN IP
to join from another machine. State is deliberately in-memory and resets
when the server exits.

Club Corvid is also available through the single-process BendJogos hub at
`http://<server-lan-ip>:8090/club-corvid`. Signed-in BendJogos accounts publish
Club Corvid as their current activity while the page is open.

## World and controls

- Visit Rookery Plaza, Moonlit Harbor, Old Library, and Acorn Arcade from the
  room tabs. Every location has its own scenery, catalog, and playful props;
  use the object labels inside the world to interact.
- Click or tap a destination in the world to waddle there. Bend clamps and
  stores the authoritative destination; avatars interpolate toward it with
  facing, alternating steps, wing movement, and a walking bounce.
- WASD, arrow keys, and the mobile directional pad remain available as
  alternatives.
- Chat is public to the current room. Recent messages appear as timed speech
  balloons attached to their speaking corvid instead of a detached history
  box. The bottom composer also has three quick-chat phrases.
- New birds receive 500 coins. The two catalog items in each room can be
  purchased once and equipped from that catalog; the selected piece is visible
  on the shared-world avatar.
- **Feather Flight** has explicit start, flight, collision, score, and retry
  states. Tap or press Space to flap; clean obstacle passes add to the
  player's authoritative Bend score and award 12 coins.
- **Shell Shuffle** has disabled/reveal/retry states so guesses cannot be
  dropped or double-submitted. Bend chooses the hidden golden acorn and
  evaluates each guess; a correct choice awards 25 coins.
- **Worm Hunt** is a timed beak-and-reflex game. Peck the moving worm before it
  burrows away; every server-recorded peck awards 8 coins.
- **Echo Perch** plays a growing four-note birdsong. Repeat the phrase in order;
  every completed sequence is recorded by Bend and awards 18 coins.
- The fountain, harbor bell, telescope, globe, reading lamp, notice board,
  jukebox, movement, chat, catalog, and every minigame action have distinct
  sound effects. Entering a room changes the background melody.

The room scenes and corvids are drawn from original Canvas and CSS artwork;
the demo has no external asset or CDN dependency.

## HTTP interface

Actions use newline-delimited UTF-8 text bodies so the browser can send names
and chat without encoding state into paths.

| Route | Body | Purpose |
| --- | --- | --- |
| `GET /` | — | Browser client |
| `GET /state/<id>` | — | Touch presence and read the shared snapshot |
| `POST /join` | `id\nname` | Join or resume a bird |
| `POST /move` | `id\ndirection` | Move north/east/south/west (`0..3`) |
| `POST /walk` | `id\nx\ny` | Walk to clamped percentage coordinates |
| `POST /room` | `id\nroom` | Visit one of four rooms (`1..4`) |
| `POST /chat` | `id\nmessage` | Send a message to the current room |
| `POST /play` | `id\ngame\naction` | Start or advance one of four minigames |
| `POST /buy` | `id\nitem` | Buy an item from the current room's catalog |
| `POST /equip` | `id\nitem` | Equip an owned item (`0` removes it) |
| `POST /leave` | `id` | Leave immediately |

## Hub interface

`web_club_corvid.bend` is importable as a module
(`import ../club_corvid_web/web_club_corvid.bend as Corvid`) and exposes:

- `Corvid.Game` — the state type (`is Data`);
- `Corvid.init()` — an empty club (pure);
- `Corvid.route(req: HTTP.Request, g: Corvid.Game) -> IO(Corvid.Game & HTTP.Response)`
  — reads the clock itself (`HTTP.serve` shape);
- `Corvid.route_at(req, g, now: U32)` — the same with an explicit clock.

Both routes accept the path with or without the leading `/club-corvid`
segment, so the hub can pass its request through unchanged. `main` is only
`HTTP.serve(~Game, ~route, "0.0.0.0", 8087, init())`.

## Bend behavior notes

The unexpected behavior encountered while building this demo, and its Bend
2.0.40 retest, are kept under
[`unexpected_behavior/`](unexpected_behavior/README.md). No Bend compiler or
runtime file was modified to make the demo work, and the 2.0.40 port uses no
`@unsafe`.
