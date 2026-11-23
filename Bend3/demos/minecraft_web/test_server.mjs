// Block World HTTP protocol check against a running server.
// usage: bun Bend3/demos/minecraft_web/test_server.mjs [base-url]
// (default http://127.0.0.1:8085; pass http://127.0.0.1:8090/minecraft for the hub)
import assert from "node:assert/strict";

const base = process.argv[2] ?? "http://127.0.0.1:8085";
const S = 24;

async function get(path) {
  const t = performance.now();
  const r = await fetch(base + path, { cache: "no-store" });
  const body = await r.text();
  return { status: r.status, body, ms: performance.now() - t, type: r.headers.get("content-type") };
}
async function json(path) {
  const r = await get(path);
  assert.equal(r.status, 200, path);
  return JSON.parse(r.body);
}

// The world formula of the Bend source, recomputed in JS.
const abs = (a, b) => (a < b ? b - a : a - b);
const trees = [[6, 6], [17, 8], [9, 17]];
function column(x, z) {
  const g = 2 + ((x * 13 + z * 7 + x * z) % 3);
  if (trees.some(([cx, cz]) => x === cx && z === cz)) return [g + 3, 4];
  if (trees.some(([cx, cz]) => abs(x, cx) <= 1 && abs(z, cz) <= 1)) return [g + 2, 5];
  return [g, 1];
}

const id = 1000 + Math.floor(Math.random() * 1e6);
const ids = [id, id + 1, id + 2, id + 3, id + 4];

const page = await get("/");
assert.equal(page.status, 200);
assert.match(page.body, /<canvas/);
assert.equal((await fetch(base + "/state/1", { method: "POST" })).status, 405);
assert.equal((await get("/nope/1")).status, 404);

let s = await json(`/state/${id}`);
assert.equal(s.size, S);
assert.equal(s.renderDistance, 6);
assert.equal(s.world.length, S * S);
for (let i = 0; i < S * S; i++) assert.deepEqual(s.world[i], column(i % S, Math.floor(i / S)), `column ${i}`);
assert.equal(s.you, 0);

s = await json(`/join/0`);
assert.equal(s.ok, 0);
assert.equal(s.note, "Invalid player identity.");
s = await json(`/move/${id}/1`);
assert.equal(s.ok, 0);
assert.equal(s.note, "Join the world before moving.");

for (let k = 0; k < 4; k++) {
  s = await json(`/join/${ids[k]}`);
  assert.equal(s.ok, 1);
  assert.equal(s.you, k + 1);
}
assert.equal(s.full, 1);
s = await json(`/join/${ids[4]}`);
assert.equal(s.ok, 0);
assert.match(s.note, /four active players/);
s = await json(`/join/${ids[0]}`); // rejoin keeps the slot
assert.equal(s.you, 1);

// Player 1 spawns at (11, 11); move east to (12, 11).
s = await json(`/move/${id}/1`);
assert.deepEqual([s.players[0].x, s.players[0].z], [12, 11]);
s = await json(`/move/${id}/0`);
assert.deepEqual([s.players[0].x, s.players[0].z], [12, 10]);
s = await json(`/move/${id}/2`);

const at = (st, x, z) => st.world[z * S + x];
const before = at(s, 12, 11);
s = await json(`/mine/${id}/12/11`);
assert.equal(s.ok, 1);
assert.equal(at(s, 12, 11)[0], before[0] - 1);
s = await json(`/place/${id}/12/11/3`);
assert.equal(s.ok, 1);
assert.deepEqual(at(s, 12, 11), [before[0], 3]);
s = await json(`/place/${id}/12/11/9`);
assert.equal(s.ok, 0);
s = await json(`/mine/${id}/0/0`);
assert.equal(s.ok, 0);
assert.equal(s.note, "That block is outside your reach.");
for (let k = 0; k < 12; k++) await json(`/place/${id}/12/12/2`);
s = await json(`/state/${id}`);
assert.equal(at(s, 12, 12)[0], 9, "max height");

// Other players see the edit.
s = await json(`/state/${ids[1]}`);
assert.equal(s.you, 2);
assert.deepEqual(at(s, 12, 11), [before[0], 3]);

for (const p of ids.slice(0, 4)) {
  s = await json(`/leave/${p}`);
  assert.equal(s.ok, 1);
  assert.equal(s.you, 0);
}
assert.equal(s.full, 0);

const times = [];
for (let k = 0; k < 200; k++) times.push((await get(`/state/${id}`)).ms);
times.sort((a, b) => a - b);
console.log(`state route: ${s.world.length} columns, median ${times[100].toFixed(2)} ms, p95 ${times[190].toFixed(2)} ms (200 requests)`);
console.log("Block World protocol checks passed.");
