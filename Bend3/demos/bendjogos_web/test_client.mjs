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
const coreBeet = fs.readFileSync(new URL("./core/bend-a-beet.html", import.meta.url), "utf8");
const coreBeetData = fs.readFileSync(new URL("./core/bend_a_beet_data.js", import.meta.url), "utf8");
const coreBeetCamera = fs.readFileSync(new URL("./core/bend_a_beet_camera.js", import.meta.url), "utf8");
assert.match(coreHome, /href="\/core\/poker"/);
assert.match(coreHome, /href="\/core\/belote"/);
assert.match(coreHome, /href="\/core\/bend-a-beet"/);
assert.match(coreHome, /Same site and port/);
assert.match(corePoker, /href="\/poker"/);
assert.match(corePoker, /Bend2 Core · pure simulation/);
assert.match(corePoker, /Machine-checked proof audit|id="proof-title"/);
for (const [index, match] of [...corePoker.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].entries()) {
  new vm.Script(match[1], { filename: `core-poker-${index}.js` });
}
const corePokerContext = { globalThis: {} };
vm.runInNewContext(coreData, corePokerContext, { filename: "core-poker-data.js" });
assert.equal(corePokerContext.globalThis.BEND2_POKER_DATA.$2.$, "ProofAudit");
assert.equal(corePokerContext.globalThis.BEND2_POKER_DATA.$2.$6, 78);
assert.match(coreBelote, /href="\/belote"/);
assert.match(coreBelote, /Bend2 Core · four AIs/);
for (const [index, match] of [...coreBelote.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].entries()) {
  new vm.Script(match[1], { filename: `core-belote-${index}.js` });
}
new vm.Script(coreBeloteData, { filename: "core-belote-data.js" });
assert.match(coreBeet, /Bend-a-Beet/);
assert.match(coreBeet, /33 machine-checked library theorems/);
assert.match(coreBeet, /src="bend_a_beet_camera\.js"/);
assert.match(coreBeet, /function ellipsoid/);
assert.match(coreBeet, /function tube/);
assert.match(coreBeet, /function responseCable/);
assert.match(coreBeet, /uShine/);
for (const [index, match] of [...coreBeet.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].entries()) {
  new vm.Script(match[1], { filename: `core-bend-a-beet-${index}.js` });
}
new vm.Script(coreBeetCamera, { filename: "core-bend-a-beet-camera.js" });
assert.match(coreBeetCamera, /pointermove/);
assert.match(coreBeetCamera, /function unproject/);
assert.match(coreBeetCamera, /function pose/);
assert.match(coreBeetCamera, /BEND_A_BEET_CAMERA/);
const coreBeetContext = { globalThis: {} };
vm.runInNewContext(coreBeetData, coreBeetContext, { filename: "core-bend-a-beet-data.js" });
assert.equal(coreBeetContext.globalThis.BEND_A_BEET_DATA.$, "GameReport");
assert.equal(coreBeetContext.globalThis.BEND_A_BEET_DATA.$4, 19);
let beetFrameCount = 0, beetFrames = coreBeetContext.globalThis.BEND_A_BEET_DATA.$8;
while (beetFrames?.$ === "Con") { beetFrameCount++; beetFrames = beetFrames.$1; }
assert.equal(beetFrameCount, 1086);
console.log("BendJogos browser-client checks passed.");
