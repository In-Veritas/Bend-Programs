# Club Corvid: issues and unexpected Bend3 behavior

## Reproduction environment

- Bend3 package version: `0.1.0`
- Bend3 compiler/base revision: `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Club Corvid feature baseline: `760449bbba9ff8732eefe4e6854646d43075ccae`
- Gameplay quality baseline: `7f3c0fc8593e3d5f689f08ac6bfcd8f29c47e341`
- Catalog/economy baseline: `a4f5f740eae4b2cba88f2c26e0586c5439062d8d`
- Recorded: 2026-07-22
- Quality review recorded: 2026-07-27
- Catalog/economy review recorded: 2026-07-28

The feature baseline contains the exact demo source and compiler used for this
observation. No Bend3 compiler or runtime file was modified while implementing
or testing it.

## Issue: the long-lived server cycle needs whole-book scoping

### Summary

The standalone HTTP server accepts a connection, routes it, sends a response,
then returns to its accept loop. Those functions necessarily form a
mutual-recursion cycle. In the default checker mode, the earlier
`routed_send` definition cannot resolve the later `u32_serve` definition.
The unchanged source checks and builds with `--no-halt`, which enables
whole-book scoping in addition to disabling the termination proof.

### Full-demo reproduction

From the repository root at the feature baseline:

```sh
git checkout 760449bbba9ff8732eefe4e6854646d43075ccae
node bend-ts/src/main.ts gabriel_demos/club_corvid_web/web_club_corvid.bend
```

The command exits with status 1:

```text
NotBound:
- name : u32_serve
Context:
- game     : Game
- response : HTTP::Response
- server   : U32
- conn     : HTTP::Conn
- sent     : Result::Result(U32)
- closed   : U32
Location: routed_send
454 |         closed : U32 <- HTTP::conn_close(conn)
455>|         u32_serve(server, game)
456 |
```

This is the same whole-book-scoping distinction already isolated by the
canonical [`mre_mutual_scope.bend`](../../minecraft_web/unexpected_behavior/mre_mutual_scope.bend).
That MRE remains in one shared location rather than being copied into every
server demo.

### Status and workaround

This is a language-mode distinction rather than a compiler patch made for the
demo. The standalone build script records the required mode explicitly with
`--no-halt`. Both the exact full source and shared minimal failing case remain
available for independent reproduction.

## Demo limitations, not Bend3 failures

- Club state is in memory and resets when the process exits.
- Browser identities are random local session IDs, not authenticated accounts.
- Feather Flight physics is rendered locally, while successful passes and the
  resulting score are authoritative in Bend.

## Issue: minigame inputs were silently discarded

### Summary

The original browser returned `null` from every action attempted while another
request was active. Opening a minigame started its Bend action without waiting
for it, so an immediate cup guess or score event could do nothing.

### Detailed explanation and reproduction

At `760449bbba9ff8732eefe4e6854646d43075ccae`, `act()` begins with:

```js
if (actionBusy) return null;
```

`openGame()` called `act("/play", ...)` and immediately exposed the game.
Check out that revision, open Shell Shuffle, and click a cup immediately. On a
normal network delay, the start request still owns `actionBusy`; the guess is
dropped without feedback or a retry.

This was a browser request-flow bug, not a Bend3 compiler/runtime failure.

### Resolution

At `7f3c0fc8593e3d5f689f08ac6bfcd8f29c47e341`, minigame opening awaits
the authoritative start response. Shell buttons disable during a guess and
show correct/wrong and next-round states. Feather Flight has explicit ready,
running, collision, score, and retry states. Server snapshots are applied by
monotonic Bend `tick`, preventing older poll responses from replacing newer
action results.

## Issue: world movement did not match the intended social-game flow

### Summary

The first version only exposed keyboard and directional-pad steps. The
point-and-click movement central to the requested inspiration was absent.

### Resolution

The Bend backend now owns `POST /walk` with `id`, X, and Y percentage
coordinates. It clamps destinations to the playable world and stores them in
the shared player value. Desktop and mobile canvas clicks use that route;
browser interpolation supplies a smooth waddle while Bend remains
authoritative.

## Remaining demo limitations

- Clients poll snapshots rather than holding WebSocket connections.
- Feather Flight physics and collision detection remain browser-side; Bend
  authoritatively records starts and successful passes.
- The two minigames use one per-session score field, reset when a different
  cabinet starts. Scores are not persistent account achievements.
- Multiplayer identities are random local browser IDs rather than BendJogos
  authenticated account identities.

## Issue: client-reported Flight passes are not suitable for a trusted economy

### Summary

The expanded demo pays 12 coins when the browser reports a successful Feather
Flight gate. Bend authoritatively applies the payout, but it cannot independently
prove that the browser actually cleared an obstacle. A custom HTTP client can
start Flight and repeatedly submit pass actions.

### Detailed explanation

At `a4f5f740eae4b2cba88f2c26e0586c5439062d8d`, the intended browser calculates
flight physics and collision locally. It calls:

```text
POST /play
<id>
1
1
```

after a pipe moves behind the bird. The server checks that the bird has started
Feather Flight and is in the Acorn Arcade, then increments the score and coin
balance. It does not receive enough timing or obstacle state to reproduce the
flight.

This is a deliberate demo security limitation, not a Bend3 compiler or runtime
failure. A production economy would move the flight simulation, inputs, and
collision validation into authoritative server state, or use a different
reward model. The limitation is recorded rather than hidden behind
browser-only verification.

## Issue: full-page screenshots can catch a transient canvas size

### Summary

Playwright's `fullPage: true` capture temporarily changes page geometry. A
Canvas frame can be captured between that resize and the next animation frame,
making the right edge look blank even though the stable viewport is correct.

### Detailed explanation and resolution

During the 2026-07-28 visual review, the functional browser smoke test passed
but its full-page desktop image showed a blank strip and clipped room label.
Runtime geometry inspection reported the correct `1101 × 790` canvas and
`1109 × 798` containing card. A normal viewport capture after one stable
animation interval filled the complete card and rendered the label correctly.

This is browser-test harness behavior, not a Bend3 or Club Corvid rendering
fault. Future visual checks for animated Canvas demos should:

1. use a fixed viewport capture instead of `fullPage: true`;
2. wait for a `requestAnimationFrame` after the final layout change; and
3. assert the Canvas and container dimensions before reviewing pixels.

Keeping this distinction avoids reporting a non-reproducible application bug
from a transient verification artifact.

## Catalog/economy demo limitations

- Club state, coin balances, purchases, and equipped items are in memory and
  reset when the process exits.
- The eight-item inventory is intentionally represented by a compact `U32`
  bitset, and one item can be equipped at a time.
- Recent room chat is capped at 24 messages. Speech balloons are ephemeral
  browser presentation of that authoritative history rather than persistent
  mail.
- Shell Shuffle's hidden choice is server-owned, but the demo is not intended
  to provide cryptographically unpredictable gambling mechanics.

## Catalog/economy verification

At `a4f5f740eae4b2cba88f2c26e0586c5439062d8d`:

- the unchanged Bend3 compiler at
  `ffa2411e9e0bd1275150b07f627c3686a145632d` checked both the standalone and
  unified BendJogos sources with `--no-halt`;
- the native server verified the 500-coin starting balance, correct-room
  purchase checks, duplicate rejection, insufficient ownership rejection,
  equipment, room chat, click-walk coordinates, a 12-coin Flight payout, and a
  25-coin Shell Shuffle payout;
- headless Chromium exercised desktop and 390 × 844 phone layouts, walking
  animation state, attached speech balloons, catalog buy/equip flow, room
  props, and a minigame without page or console errors; and
- the full Bend3 repository suite passed 506/506.

## Quality-baseline verification

At `7f3c0fc8593e3d5f689f08ac6bfcd8f29c47e341`:

- the unchanged compiler checks the source with `--no-halt`;
- the native server accepted join, click-walk, Flight start/score, Shell start,
  and leave actions with strict JSON responses;
- headless Chromium completed click movement, opened and interacted with both
  minigames, rendered without page errors, and passed a 390×844 phone layout
  check; and
- the full Bend3 repository suite passed 506/506.
