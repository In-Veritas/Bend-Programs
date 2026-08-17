import assert from "node:assert/strict";

const base = process.env.BELOTE_URL || "http://127.0.0.1:8091";
async function get(path) {
  const response = await fetch(base + path, { cache: "no-store" });
  assert.equal(response.status, 200, `${path} returned ${response.status}`);
  return response.json();
}

async function settle(next) {
  let state = next;
  for (let step = 0; step < 64 && state.phase <= 2 && state.turn !== 0; step++) {
    state = await get("/auto");
  }
  return state;
}

let state = await get("/new");
assert.equal(typeof state.seed, "number", "new match must expose its Bend IO seed");
assert.equal(state.counts.reduce((sum, count) => sum + count, 0), 20);
if (state.phase === 0 && state.turn === 0) {
  state = await settle(await get(`/bid/${state.offered + 1}`));
} else if (state.phase === 1 && state.turn === 0) {
  const suit = [0, 1, 2, 3].find((candidate) => candidate !== state.offered);
  state = await settle(await get(`/bid/${suit + 1}`));
}
assert.equal(state.phase, 2, "a valid human take should start card play");
assert.equal(state.counts.reduce((sum, count) => sum + count, 0), 32);

let humanPlays = 0;
while (state.phase === 2 && humanPlays < 8) {
  assert.equal(state.turn, 0, "AI auto-play should stop at South's turn");
  let played = false;
  for (const card of state.hand) {
    const next = await get(`/play/${card}`);
    if (next.ok) {
      state = await settle(next);
      played = true;
      humanPlays++;
      break;
    }
  }
  assert.ok(played, "South must always have at least one legal card");
}

assert.ok(state.phase === 3 || state.phase === 4, "eight tricks should finish the hand");
assert.equal(humanPlays, 8);
assert.equal(state.tricks, 8);
assert.equal(state.points[0] + state.points[1], 162);
assert.deepEqual(state.counts, [0, 0, 0, 0]);
console.log(`Belote HTTP hand completed: ${state.points[0]}–${state.points[1]}, match ${state.scores[0]}–${state.scores[1]}.`);
const fresh = await get("/new");
assert.ok(fresh.phase <= 1, "HTTP smoke must leave a fresh playable table behind");
