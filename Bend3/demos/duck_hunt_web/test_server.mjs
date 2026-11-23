import assert from "node:assert/strict";
const base = process.argv[2] || "http://127.0.0.1:8089";
const get = async (p) => { const r = await fetch(base + p); const t = await r.text(); let j = null; try { j = JSON.parse(t) } catch {} return { status: r.status, t, j }; };
const A = 123456, B = 654321;
let r = await get("/"); assert.equal(r.status, 200); assert.match(r.t, /Duck Hunt|duck/i);
r = await get("/duck-hunt"); assert.equal(r.status, 200);
r = await get(`/duck-hunt/state/${A}`); assert.equal(r.j.ok, 1); assert.equal(r.j.player.status, 0); assert.equal(r.j.player.required, 6); assert.equal(r.j.player.seed, A);
r = await get(`/duck-hunt/shoot/${A}/1/3`); assert.equal(r.j.ok, 0); assert.equal(r.j.note, "Start a hunt before shooting.");
r = await get(`/duck-hunt/next/${A}`); assert.equal(r.j.note, "Start a hunt first.");
r = await get(`/duck-hunt/start/0`); assert.equal(r.j.note, "Invalid hunter identity.");
r = await get(`/duck-hunt/start/${A}`); assert.equal(r.j.ok, 1); assert.equal(r.j.player.status, 1); assert.equal(r.j.player.ammo, 3);
r = await get(`/duck-hunt/next/${A}`); assert.equal(r.j.note, "This duck is still in flight.");
// duck 1: three misses -> escaped
r = await get(`/duck-hunt/shoot/${A}/0/0`); assert.equal(r.j.note, "Miss. Track the flight and try again."); assert.equal(r.j.player.ammo, 2);
r = await get(`/duck-hunt/shoot/${A}/0/0`); r = await get(`/duck-hunt/shoot/${A}/0/0`);
assert.equal(r.j.note, "Out of shells. The duck escaped."); assert.equal(r.j.player.status, 2); assert.equal(r.j.player.ammo, 0);
r = await get(`/duck-hunt/shoot/${A}/1/3`); assert.equal(r.j.note, "Wait for the next duck.");
r = await get(`/duck-hunt/next/${A}`); assert.equal(r.j.note, "Next duck."); assert.equal(r.j.player.duck, 2); assert.equal(r.j.player.ammo, 3);
// ducks 2..10: hits with band 3 (round 1: 450+750+50 = 1250 each)
for (let d = 2; d <= 10; d++) {
  r = await get(`/duck-hunt/shoot/${A}/1/9`); assert.equal(r.j.note, "Direct hit."); assert.equal(r.j.player.status, 2);
  if (d < 10) { r = await get(`/duck-hunt/next/${A}`); assert.equal(r.j.player.duck, d + 1); }
}
assert.equal(r.j.player.score, 9 * 1250); assert.equal(r.j.player.roundHits, 9); assert.equal(r.j.high, 11250); assert.equal(r.j.highPlayer, A);
r = await get(`/duck-hunt/next/${A}`); assert.equal(r.j.note, "Round clear. The next flock is faster."); assert.equal(r.j.player.round, 2); assert.equal(r.j.player.duck, 1); assert.equal(r.j.player.roundHits, 0);
// round 2: hits on ducks 1..3 with band 0 (450+0+100 = 550), then misses -> game over
for (let d = 1; d <= 10; d++) {
  if (d <= 3) { r = await get(`/shoot/${A}/1/0`); assert.equal(r.j.note, "Direct hit."); }
  else { for (let s = 0; s < 3; s++) r = await get(`/shoot/${A}/0/2`); assert.equal(r.j.player.status, 2); }
  r = await get(`/next/${A}`);
}
assert.equal(r.j.note, "The dog closes the book on this hunt."); assert.equal(r.j.player.status, 3);
assert.equal(r.j.player.score, 11250 + 3 * 550); assert.equal(r.j.player.best, 12900); assert.equal(r.j.player.totalHits, 12);
// second hunter sees the shared high score; restart keeps best
r = await get(`/duck-hunt/state/${B}`); assert.equal(r.j.high, 12900); assert.equal(r.j.highPlayer, A); assert.equal(r.j.player.score, 0);
r = await get(`/duck-hunt/start/${A}`); assert.equal(r.j.player.score, 0); assert.equal(r.j.player.best, 12900); assert.equal(r.j.player.round, 1);
r = await get(`/duck-hunt/start/${B}`); r = await get(`/duck-hunt/shoot/${B}/1/1`); assert.equal(r.j.player.score, 750); assert.equal(r.j.high, 12900);
r = await get(`/duck-hunt/leave/${A}`); assert.equal(r.j.ok, 1); assert.equal(r.j.player.status, 0); assert.equal(r.j.player.best, 0);
r = await get(`/duck-hunt/state/${B}`); assert.equal(r.j.player.score, 750);
r = await get(`/duck-hunt/shoot/${B}/1`); assert.equal(r.status, 404);
r = await get(`/duck-hunt/fly/${B}`); assert.equal(r.status, 404);
r = await fetch(base + "/duck-hunt/state/1", { method: "POST" }); assert.equal(r.status, 405);
console.log("final:", (await get(`/duck-hunt/state/${B}`)).t);
console.log("duck hunt: all checks passed");
