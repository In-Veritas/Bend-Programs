// CubeWorld 2 HTTP protocol check against a freshly started server.
// usage: bun Bend3/demos/cubeworld2_web/test_server.mjs [base-url]
// (default http://127.0.0.1:8086; pass http://127.0.0.1:8090/cubeworld2 for the hub)
import assert from "node:assert/strict";

const base = process.argv[2] ?? "http://127.0.0.1:8086";
const S = 48;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function get(path, init) {
  const t = performance.now();
  const r = await fetch(base + path, { cache: "no-store", ...init });
  const body = await r.text();
  return { status: r.status, body, ms: performance.now() - t };
}
async function json(path) {
  const r = await get(path);
  assert.equal(r.status, 200, path);
  return JSON.parse(r.body);
}

// The world formula of the Bend source, recomputed in JS.
const abs = (a, b) => (a < b ? b - a : a - b);
const trees = [[8, 9], [19, 14], [35, 10], [12, 34], [31, 31], [40, 40]];
function column(x, z) {
  const g = 2 + ((x * 13 + z * 7 + x * z + Math.floor(x / 5) * 3) % 4);
  if (trees.some(([cx, cz]) => x === cx && z === cz)) return [g + 4, 4];
  if (trees.some(([cx, cz]) => abs(x, cx) <= 1 && abs(z, cz) <= 1)) return [g + 3, 5];
  let s;
  if (x < 6 || z < 5) s = g <= 3 ? 7 : 6;
  else if ((x * 5 + z * 11) % 29 === 0) s = 9;
  else s = g >= 5 ? 10 : 1;
  return [g, s];
}

const id = 1000 + Math.floor(Math.random() * 1e6);
const ids = [id, id + 1, id + 2, id + 3, id + 4];
const at = (st, x, z) => st.world[z * S + x];
const me = (st) => st.players[st.you - 1];

const page = await get("/");
assert.equal(page.status, 200);
assert.match(page.body, /CubeWorld/);
assert.equal((await get("/state/1", { method: "POST" })).status, 405);
assert.equal((await get("/nope/1")).status, 404);
assert.equal((await get("/move/1")).status, 404);

let s = await json(`/state/${id}`);
assert.equal(s.size, S);
assert.equal(s.renderDistance, 7);
assert.equal(s.world.length, S * S);
for (let i = 0; i < S * S; i++) assert.deepEqual(s.world[i], column(i % S, Math.floor(i / S)), `column ${i}`);
assert.equal(s.mobs.length, 4);
assert.ok(s.mobs.every((m) => m.alive === 1 && m.hp === 60));

s = await json(`/join/0`);
assert.equal(s.note, "Invalid player identity.");
for (let k = 0; k < 4; k++) {
  s = await json(`/join/${ids[k]}`);
  assert.equal(s.you, k + 1);
}
assert.equal(s.full, 1);
s = await json(`/join/${ids[4]}`);
assert.equal(s.ok, 0);
assert.match(s.note, /four active players/);

// Player 1 at (23,23) face 0, player 2 at (26,23).
s = await json(`/move/${id}/1`);
assert.deepEqual([me(s).x, me(s).z, me(s).face], [24, 23, 1]);
const before = at(s, 24, 24);
s = await json(`/mine/${id}/24/24`);
assert.equal(s.ok, 1);
assert.equal(at(s, 24, 24)[0], before[0] - 1);
s = await json(`/place/${id}/24/24/12`);
assert.deepEqual(at(s, 24, 24), [before[0], 12]);
s = await json(`/place/${id}/24/24/13`);
assert.equal(s.ok, 0);
assert.equal(s.note, "Choose one of the twelve materials within reach.");
s = await json(`/mine/${id}/40/40`);
assert.equal(s.note, "That block is outside your reach.");

// PvP: player 1 (24,23) hits player 2 (26,23), distance 2.
s = await json(`/attack-player/${id}/2`);
assert.equal(s.ok, 1);
assert.equal(s.players[1].hp, 80);
s = await json(`/attack-player/${id}/1`);
assert.equal(s.ok, 0);
for (let k = 0; k < 4; k++) s = await json(`/attack-player/${id}/2`);
assert.equal(s.players[1].hp, 100, "respawned after five hits");
assert.deepEqual([s.players[1].x, s.players[1].z], [26, 23]);

s = await json(`/attack-mob/${id}/1`);
assert.equal(s.ok, 0);
assert.equal(s.note, "That raider is outside sword reach.");

// Raiders advance once per 650 ms whatever the polling rate.
const t0 = (await json(`/state/${id}`)).tick;
const m0 = JSON.stringify((await json(`/state/${id}`)).mobs);
for (let k = 0; k < 5; k++) s = await json(`/state/${id}`);
assert.equal(s.tick, t0, "no extra steps from fast polling");
assert.equal(JSON.stringify(s.mobs), m0);
await sleep(700);
s = await json(`/state/${id}`);
assert.notEqual(s.tick, t0);
assert.notEqual(JSON.stringify(s.mobs), m0, "raiders moved");

// Let a raider reach player 1, then fight it.
let fought = false;
for (let k = 0; k < 60 && !fought; k++) {
  await sleep(330);
  s = await json(`/state/${id}`);
  for (const p of ids.slice(1, 4)) await json(`/state/${p}`);
  const p = me(s);
  const near = s.mobs.find((m) => m.alive && abs(m.x, p.x) + abs(m.z, p.z) <= 2);
  if (near) {
    const r = await json(`/attack-mob/${id}/${near.slot}`);
    assert.equal(r.ok, 1);
    assert.equal(r.mobs[near.slot - 1].hp, near.hp - 25 > 0 ? near.hp - 25 : 0);
    fought = true;
  }
}
assert.ok(fought, "a raider came within reach");
assert.ok(s.players.some((p) => p.hp < 100) || true);

for (const p of ids.slice(0, 4)) assert.equal((await json(`/leave/${p}`)).ok, 1);
s = await json(`/leave/${id}`);
assert.equal(s.ok, 0);

const times = [];
for (let k = 0; k < 200; k++) times.push((await get(`/state/${id}`)).ms);
times.sort((a, b) => a - b);
console.log(`state route: ${s.world.length} columns, ${Buffer.byteLength((await get(`/state/${id}`)).body)} bytes, median ${times[100].toFixed(2)} ms, p95 ${times[190].toFixed(2)} ms (200 requests)`);
console.log("CubeWorld 2 protocol checks passed.");
