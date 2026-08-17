import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const html = fs.readFileSync(new URL("./index.html", import.meta.url), "utf8");
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
assert.ok(scripts.length >= 1, "Belote client script not found");
new vm.Script(scripts[0][1], { filename: "belote-client.js" });
for (const marker of ["/bid/", "/play/", "/auto", "650", "/new", "New random match", "Trump", "Belote/Rebelote", "Match to 501"]) {
  assert.ok(html.includes(marker), `missing ${marker}`);
}
console.log("Belote browser-client checks passed.");
