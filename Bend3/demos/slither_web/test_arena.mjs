// Shared test for slither (snake) and agar (cells) arenas.
// usage: bun test_arena.mjs snake|cells [base]
import assert from "node:assert/strict";
const kind = process.argv[2];
const base = process.argv[3] || (kind === "snake" ? "http://127.0.0.1:8083" : "http://127.0.0.1:8084");
const pre = "/" + kind;
const get = async (p) => { const r = await fetch(base + p); const t = await r.text(); let j = null; try { j = JSON.parse(t) } catch {} return { status: r.status, t, j }; };
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const head = (s) => kind === "snake" ? s.body[0] : [s.x, s.y];
const heading = (from, to) => { const a = Math.atan2(to[1] - from[1], to[0] - from[0]); return ((Math.round(a / (Math.PI / 8)) % 16) + 16) % 16; };
let r = await get("/"); assert.equal(r.status, 200); assert.match(r.t, /<html/i);
r = await get(pre); assert.equal(r.status, 200);
r = await get(`${pre}/input/1/3`); assert.equal(r.j.ok, 0); assert.equal(r.j.note, "Join the game before moving.");
r = await get(`${pre}/leave/1`); assert.equal(r.j.ok, 0);
r = await get(`${pre}/join/0`); assert.equal(r.j.ok, 0); assert.equal(r.j.note, "Invalid player identity.");
const ids = [101, 202, 303, 404];
for (let i = 0; i < 4; i++) { r = await get(`${pre}/join/${ids[i]}`); assert.equal(r.j.ok, 1); assert.equal(r.j.you, i + 1); }
assert.equal(r.j.full, 1);
r = await get(`/join/505`); assert.equal(r.j.ok, 0); assert.equal(r.j.note, "The arena already has four players.");
r = await get(`${pre}/join/202`); assert.equal(r.j.ok, 1); assert.equal(r.j.you, 2);
r = await get(`${pre}/leave/404`); assert.equal(r.j.ok, 1); assert.equal(r.j.full, 0); assert.equal(r.j.players[3].joined, 0);
r = await get(`${pre}/leave/202`); assert.equal(r.j.ok, 1);
const t0 = r.j.tick;
await sleep(350);
r = await get(`${pre}/state/101`); const dt = r.j.tick - t0; assert.ok(dt >= 4 && dt <= 6, "ticks " + dt);
console.log(`ticks advance: ${dt} in ~350ms`);
// Player 1 hunts food, player 3 hunts player 1; 303 stays active; watch for food, deaths, respawns.
let ate = false, died = new Set(), respawned = false, collision = false, walls = false, lastScore = 0, maxTick = 0;
const start = Date.now();
while (Date.now() - start < 30000) {
  const st = (await get(`${pre}/state/101`)).j;
  maxTick = Math.max(maxTick, st.tick);
  const p1 = st.players[0], p3 = st.players[2];
  const sc = kind === 'snake' ? p1.score : p1.mass - 5; if (p1.alive && sc > lastScore && !died.has(1)) { ate = true; lastScore = sc; }
  for (const p of [p1, p3]) if (!p.alive && p.joined) {
    if (!died.has(p.slot)) { died.add(p.slot); console.log(`slot ${p.slot} died at tick ${st.tick}, respawn ${p.respawn}`); }
  }
  for (const p of [p1, p3]) if (died.has(p.slot) && p.alive) respawned = true;
  let h1 = 0, h3 = 8;
  if (p1.alive) {
    const hd = head(p1);
    if (!ate || (kind === 'cells' && lastScore < 4)) { let best = null, bd = 1e9; for (const f of st.food) { const d = (f[0]-hd[0])**2 + (f[1]-hd[1])**2; if (d < bd) { bd = d; best = f; } } h1 = heading(hd, best); }
    else if (!walls) { h1 = 0; }  // after eating, drive into the east wall
  }
  if (p3.alive && p1.alive) h3 = heading(head(p3), head(p1));
  const a = await get(`${pre}/input/101/${h1}`), b = await get(`${pre}/input/303/${h3}`);
  if (died.has(1) && ate && !walls) { walls = true; }
  if (ate && died.size && respawned) break;
  await sleep(60);
}
console.log({ ate, lastScore, died: [...died], respawned, maxTick });
assert.ok(ate, "player 1 ate food (score grew)");
assert.ok(died.size > 0, "a collision killed someone");
assert.ok(respawned, "a dead player respawned");
r = await get(`${pre}/state/101`);
if (kind === "snake") assert.ok(r.j.players[0].body.length >= 18);
else assert.ok(r.j.players[0].mass >= 5);
assert.equal(r.j.food.length, kind === "snake" ? 36 : 54);
// Expiry: player 303 stops polling; 101 keeps polling for 21 s.
console.log("waiting 21 s for the idle slot to expire...");
const e0 = Date.now();
while (Date.now() - e0 < 21500) { r = await get(`${pre}/state/101`); await sleep(500); }
assert.equal(r.j.players[2].joined, 0, "idle slot expired"); assert.equal(r.j.players[0].joined, 1);
r = await get(`${pre}/nope/1`); assert.equal(r.status, 404);
r = await fetch(base + `${pre}/state/1`, { method: "POST" }); assert.equal(r.status, 405);
console.log(kind, "arena: all checks passed");
