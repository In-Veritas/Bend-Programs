import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const html = fs.readFileSync(new URL("./index.html", import.meta.url), "utf8");
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
for (const [index, script] of scripts.entries()) {
  new vm.Script(script[1], { filename: `bendjogos-client-${index}.js` });
}
assert.match(html, /href="\/belote"/);
assert.match(html, /href="\/poker"/);
assert.match(html, /href="\/core"/);
assert.match(html, /option value="belote"/);
assert.match(html, /option value="poker"/);
assert.equal((html.match(/belote-card c[123]/g) || []).length, 3);
assert.match(html, /four musical locations/);
assert.match(html, /arithmetic constants/);

const coreHome = fs.readFileSync(new URL("./core/index.html", import.meta.url), "utf8");
const corePoker = fs.readFileSync(new URL("./core/poker.html", import.meta.url), "utf8");
const coreData = fs.readFileSync(new URL("./core/poker_data.js", import.meta.url), "utf8");
const coreBelote = fs.readFileSync(new URL("./core/belote.html", import.meta.url), "utf8");
const coreBeloteData = fs.readFileSync(new URL("./core/belote_data.js", import.meta.url), "utf8");
assert.match(coreHome, /href="\/core\/poker"/);
assert.match(coreHome, /href="\/core\/belote"/);
assert.match(coreHome, /Same site and port/);
assert.match(corePoker, /href="\/poker"/);
assert.match(corePoker, /Bend2 Core · pure simulation/);
for (const [index, match] of [...corePoker.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].entries()) {
  new vm.Script(match[1], { filename: `core-poker-${index}.js` });
}
new vm.Script(coreData, { filename: "core-poker-data.js" });
assert.match(coreBelote, /href="\/belote"/);
assert.match(coreBelote, /Bend2 Core · four AIs/);
for (const [index, match] of [...coreBelote.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].entries()) {
  new vm.Script(match[1], { filename: `core-belote-${index}.js` });
}
new vm.Script(coreBeloteData, { filename: "core-belote-data.js" });
console.log("BendJogos browser-client checks passed.");
