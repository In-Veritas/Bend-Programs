import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const html = fs.readFileSync(new URL("./index.html", import.meta.url), "utf8");
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
assert.ok(scripts.length >= 1, "Club Corvid client script not found");
new vm.Script(scripts[0][1], { filename: "club-corvid-client.js" });

for (const id of ["soundToggle", "wormModal", "wormTarget", "echoModal", "startEcho"]) {
  assert.match(html, new RegExp(`id=["']${id}["']`), `missing ${id}`);
}
for (const game of ["Feather Flight", "Shell Shuffle", "Worm Hunt", "Echo Perch"]) {
  assert.match(html, new RegExp(game), `missing ${game}`);
}
assert.match(html, /AudioContext|webkitAudioContext/, "Web Audio engine missing");
assert.match(html, /sound\.effect\('bell'\)|sound\.effect\(kind\)/, "prop effects missing");

console.log("Club Corvid browser-client checks passed.");
