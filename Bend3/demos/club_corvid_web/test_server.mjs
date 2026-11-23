// Club Corvid HTTP protocol check against a freshly started server.
// usage: bun Bend3/demos/club_corvid_web/test_server.mjs [base-url]
// (default http://127.0.0.1:8087; pass http://127.0.0.1:8090/club-corvid for the hub)
import assert from "node:assert/strict";

const base = process.argv[2] ?? "http://127.0.0.1:8087";

async function raw(path, init) {
  const t = performance.now();
  const r = await fetch(base + path, { cache: "no-store", ...init });
  return { status: r.status, body: await r.text(), ms: performance.now() - t };
}
async function post(path, ...parts) {
  const r = await raw(path, { method: "POST", headers: { "Content-Type": "text/plain;charset=utf-8" }, body: parts.join("\n") });
  assert.equal(r.status, 200, path);
  return JSON.parse(r.body);
}
async function state(id) {
  const r = await raw(`/state/${id}`);
  assert.equal(r.status, 200);
  return JSON.parse(r.body);
}
const me = (s) => s.players.find((p) => p.id === s.you);

const id = 1000 + Math.floor(Math.random() * 1e6);
const friend = id + 1;

const page = await raw("/");
assert.equal(page.status, 200);
assert.match(page.body, /Club Corvid/);
assert.equal((await raw("/state/1", { method: "PUT" })).status, 405);
assert.equal((await raw("/nope", { method: "POST", body: "1" })).status, 404);

let s = await state(id);
assert.deepEqual([s.ok, s.you, s.room], [1, 0, 1]);
assert.deepEqual(s.messages, []);

s = await post("/join", id, "x");
assert.equal(s.ok, 0);
assert.match(s.note, /2 to 18 characters/);
s = await post("/join", id, "Corvo Corvídeo");
assert.equal(s.ok, 1);
assert.equal(s.note, "Welcome to Club Corvid!");
assert.deepEqual([me(s).name, me(s).room, me(s).x, me(s).y, me(s).coins, me(s).online], ["Corvo Corvídeo", 1, 50, 48, 500, 1]);
s = await post("/join", id, "Corvo");
assert.equal(s.note, "Welcome back to the flock.");
s = await post("/join", friend, "Rook");
assert.equal(s.players.length, 2);

s = await post("/move", id, 1);
assert.deepEqual([me(s).x, me(s).y], [53, 48]);
s = await post("/move", id, 0);
assert.deepEqual([me(s).x, me(s).y], [53, 45]);
s = await post("/walk", id, 200, 1);
assert.deepEqual([me(s).x, me(s).y], [92, 18], "clamped");
s = await post("/move", 999999999, 1);
assert.equal(s.note, "Join the club before waddling.");

s = await post("/chat", id, "Olá, bando! 🐦");
assert.equal(s.ok, 1);
assert.equal(s.messages[0].text, "Olá, bando! 🐦");
assert.equal(s.messages[0].author, "Corvo Corvídeo");
s = await post("/chat", id, "x".repeat(121));
assert.equal(s.ok, 0);
s = await post("/chat", id, 'quote " and \\ backslash');
assert.equal(s.messages.length, 2);
assert.equal(s.messages[0].text, 'quote " and \\ backslash');
for (let k = 0; k < 30; k++) await post("/chat", friend, `m${k}`);
s = await state(id);
assert.equal(s.messages.length, 24, "chat history keeps 24");

// Buying: item 1 (120) and 2 (180) live in room 1.
s = await post("/buy", id, 3);
assert.equal(s.note, "Visit the item's room catalog before buying it.");
s = await post("/buy", id, 1);
assert.equal(s.ok, 1);
assert.deepEqual([me(s).coins, me(s).owned], [380, 2]);
s = await post("/buy", id, 1);
assert.equal(s.note, "You already own that item.");
s = await post("/buy", id, 9);
assert.equal(s.note, "That catalog item does not exist.");
s = await post("/equip", id, 2);
assert.equal(s.note, "Buy that item before wearing it.");
s = await post("/equip", id, 1);
assert.equal(me(s).equipped, 1);
s = await post("/equip", id, 0);
assert.equal(me(s).equipped, 0);
s = await post("/buy", id, 2);
assert.equal(me(s).coins, 200);

s = await post("/play", id, 1, 0);
assert.equal(s.note, "Visit the Acorn Arcade before using a cabinet.");
s = await post("/room", id, 4);
assert.deepEqual([s.room, me(s).x, me(s).y], [4, 50, 48]);
assert.ok(s.messages.every((m) => m.room === 4));
s = await post("/play", id, 5, 0);
assert.equal(s.note, "That cabinet is closed.");

// Feather Flight
s = await post("/play", id, 1, 0);
assert.deepEqual([me(s).game, me(s).score], [1, 0]);
for (let k = 0; k < 3; k++) s = await post("/play", id, 1, 1);
assert.deepEqual([me(s).score, me(s).coins], [3, 236]);
// Shell Shuffle: try all three cups until one wins.
s = await post("/play", id, 2, 0);
assert.equal(me(s).game, 2);
let coins = me(s).coins;
let won = false;
for (let k = 0; k < 12 && !won; k++) {
  s = await post("/play", id, 2, 1 + (k % 3));
  if (me(s).coins === coins + 25) won = true;
  else assert.equal(me(s).coins, coins);
}
assert.ok(won, "a shell guess won");
// Worm Hunt
s = await post("/play", id, 3, 0);
coins = me(s).coins;
s = await post("/play", id, 3, 4);
assert.deepEqual([me(s).game, me(s).score, me(s).coins], [3, 1, coins + 8]);
// Echo Perch
s = await post("/play", id, 4, 0);
s = await post("/play", id, 4, 1);
s = await post("/play", id, 4, 1);
assert.deepEqual([me(s).game, me(s).score, me(s).coins], [4, 2, coins + 8 + 36]);
// A move leaves the cabinet; wrong-cabinet actions only touch.
s = await post("/play", id, 1, 1);
assert.deepEqual([me(s).game, me(s).score], [4, 2]);
s = await post("/room", id, 9);
assert.equal(s.room, 1, "invalid room falls back to the plaza");

s = await post("/leave", id);
assert.equal(s.note, "See you next migration.");
assert.equal(s.you, 0);
s = await post("/leave", id);
assert.equal(s.note, "This bird is not in the club.");

// Twelve-bird limit.
for (let k = 0; k < 11; k++) assert.equal((await post("/join", id + 10 + k, `Bird ${k}`)).ok, 1);
s = await post("/join", id + 50, "Late bird");
assert.equal(s.ok, 0);
assert.equal(s.players.length, 12);

const times = [];
for (let k = 0; k < 200; k++) times.push((await raw(`/state/${friend}`)).ms);
times.sort((a, b) => a - b);
console.log(`state route: 12 birds + 24 messages, median ${times[100].toFixed(2)} ms, p95 ${times[190].toFixed(2)} ms (200 requests)`);
console.log("Club Corvid protocol checks passed.");
