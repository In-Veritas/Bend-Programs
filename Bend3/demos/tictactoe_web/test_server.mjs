import assert from "node:assert/strict";
const base = process.argv[2] || "http://127.0.0.1:8082";
const get = async (p) => { const r = await fetch(base + p); const t = await r.text(); return { status: r.status, t, j: (()=>{try{return JSON.parse(t)}catch{return null}})() }; };
const X = 111, O = 222, Z = 333;
let r = await get("/"); assert.equal(r.status, 200); assert.match(r.t, /<html/i);
r = await get("/tic/"); assert.equal(r.status, 200);
r = await get(`/tic/state/${X}`); assert.equal(r.j.ok, 1); assert.equal(r.j.you, 0); assert.deepEqual(r.j.board, [0,0,0,0,0,0,0,0,0]);
r = await get(`/tic/join/x/${X}`); assert.equal(r.j.ok, 1); assert.equal(r.j.you, 1); assert.equal(r.j.started, 0);
r = await get(`/tic/move/${X}/0`); assert.equal(r.j.ok, 0); assert.equal(r.j.note, "Waiting for the other player.");
r = await get(`/tic/join/x/${O}`); assert.equal(r.j.ok, 0); assert.equal(r.j.note, "X is already taken.");
r = await get(`/join/o/${O}`); assert.equal(r.j.ok, 1); assert.equal(r.j.you, 2); assert.equal(r.j.started, 1);
r = await get(`/tic/join/x/${Z}`); assert.equal(r.j.ok, 0);
r = await get(`/tic/move/${O}/4`); assert.equal(r.j.note, "It is not your turn.");
for (const [p, c] of [[X,0],[O,4],[X,1]]) { r = await get(`/tic/move/${p}/${c}`); assert.equal(r.j.ok, 1, r.t); }
r = await get(`/tic/move/${O}/1`); assert.equal(r.j.note, "That square is already taken.");
r = await get(`/tic/move/${O}/9`); assert.equal(r.j.note, "That square is outside the board.");
r = await get(`/tic/move/${O}/8`); assert.equal(r.j.ok, 1);
r = await get(`/tic/again/${X}`); assert.equal(r.j.note, "Finish this round before asking for a rematch.");
r = await get(`/tic/move/${X}/2`); assert.equal(r.j.ok, 1); assert.equal(r.j.winner, 1); assert.deepEqual(r.j.board, [1,1,1,0,2,0,0,0,2]);
console.log("X wins:", r.t);
r = await get(`/tic/move/${O}/5`); assert.equal(r.j.note, "This round is finished.");
r = await get(`/tic/again/${X}`); assert.equal(r.j.xAgain, 1); assert.equal(r.j.oAgain, 0); assert.equal(r.j.winner, 1);
r = await get(`/tic/again/${O}`); assert.equal(r.j.round, 2); assert.equal(r.j.winner, 0); assert.deepEqual(r.j.board, [0,0,0,0,0,0,0,0,0]);
// draw: X O X / X O O / O X X
const seq = [[X,0],[O,1],[X,2],[O,4],[X,3],[O,5],[X,7],[O,6],[X,8]];
for (const [p,c] of seq) { r = await get(`/tic/move/${p}/${c}`); assert.equal(r.j.ok, 1, r.t); }
assert.equal(r.j.winner, 3); console.log("draw:", r.t);
r = await get(`/tic/leave/${Z}`); assert.equal(r.j.ok, 0);
r = await get(`/tic/leave/${O}`); assert.equal(r.j.ok, 1); assert.equal(r.j.o, 0); assert.equal(r.j.round, 3);
r = await get(`/tic/nope/1`); assert.equal(r.status, 404);
r = await get(`/tic/state`); assert.equal(r.status, 404);
r = await fetch(base + "/tic/state/1", {method: "POST", body: "x"}); assert.equal(r.status, 405);
r = await get(`/tic/state/abc`); assert.equal(r.j.you, 0);
console.log("tic-tac-toe: all checks passed");
