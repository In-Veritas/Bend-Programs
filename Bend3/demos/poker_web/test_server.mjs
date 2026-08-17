import assert from "node:assert/strict";

const base = process.env.POKER_URL || "http://127.0.0.1:8092";
async function get(path) {
  const response = await fetch(base + path, { cache: "no-store" });
  assert.equal(response.status, 200, `${path} returned ${response.status}`);
  return response.json();
}

let state = await get("/state/0/0");
const page = await fetch(base, { cache: "no-store" });
assert.equal(page.status, 200);
assert.match(await page.text(), /Bend3 Poker Room/);
assert.equal(state.players.length, 4);
assert.equal(state.players[0].cards.length, state.variant ? 4 : 2);
assert.ok(state.players.slice(1).every(player => player.cards.length === 0), "opponent cards leaked before showdown");
assert.equal(new Set(state.players.map(player => player.name)).size, 4, "the table should select distinct personas");

const claimed = await get("/claim/2");
assert.equal(claimed.ok, 1);
assert.equal(claimed.authorized, 1);
assert.ok(claimed.seatToken > 0);
const privateNorth = await get(`/state/2/${claimed.seatToken}`);
assert.equal(privateNorth.players[2].cards.length, privateNorth.variant ? 4 : 2);
assert.equal(privateNorth.players[1].cards.length, 0);

// Seat 0 remains the active smoke-test player. Check/call/fold as needed until
// the server reaches showdown; Bend automatically performs every unclaimed AI turn.
let actions = 0;
while (state.phase < 4 && actions < 80) {
  state = await get("/state/0/0");
  if (state.phase >= 4) break;
  if (state.turn !== 0) {
    // Claimed seat 2 can be responsible for a turn in this same hand.
    if (state.turn === 2) {
      const north = await get(`/state/2/${claimed.seatToken}`);
      const player = north.players[2], call = north.currentBet - player.bet;
      state = await get(`/action/2/${claimed.seatToken}/${call ? 2 : 1}/0`);
      actions++;
      continue;
    }
    throw new Error(`AI auto-play stopped unexpectedly on seat ${state.turn}`);
  }
  const me = state.players[0], call = state.currentBet - me.bet;
  state = await get(`/action/0/0/${call ? 2 : 1}/0`);
  assert.equal(state.ok, 1, state.note);
  actions++;
}
assert.equal(state.phase, 4, "the hand should reach showdown");
assert.ok(state.players.every(player => player.cards.length === (state.variant ? 4 : 2)), "showdown must reveal all hands");
assert.equal(state.players.filter(player => player.winner).length >= 1, true);

const omaha = await get("/new/0/0/1");
assert.equal(omaha.variant, 1);
assert.equal(omaha.players[0].cards.length, 4);
assert.equal(omaha.board.length, 0);
console.log(`Poker HTTP regression completed a ${actions}-decision Texas hand and dealt Omaha.`);
