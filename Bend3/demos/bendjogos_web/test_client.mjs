import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const read = name => fs.readFileSync(new URL(name, import.meta.url), "utf8");
const listLength = value => {
  let count = 0;
  while (value?.$ === "Con") {
    count++;
    value = value.$1;
  }
  return count;
};
const checkInlineScripts = (source, label) => {
  for (const [index, match] of [...source.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].entries()) {
    new vm.Script(match[1], { filename: `${label}-${index}.js` });
  }
};

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
const coreBendio = read("./core/bendio-3d-land.html");
const coreBendioData = read("./core/bendio_data.js");
const coreBirds = read("./core/bendy-birds.html");
const coreBirdsData = read("./core/bendy_birds_data.js");
const coreBirdsResult = read("./core/bendy_birds_result.js");
const coreFishing = read("./core/bend-fishing.html");
const coreFishingData = read("./core/bend_fishing_data.js");
const coreAquarium = read("./core/bend-aquarium.html");
const coreAquariumData = read("./core/bend_aquarium_data.js");
const coreLandscape = read("./core/bend-landscape.html");
const coreLandscapeData = read("./core/landscape_data.js");
assert.match(coreHome, /href="\/core\/poker"/);
assert.match(coreHome, /href="\/core\/belote"/);
assert.match(coreHome, /href="\/core\/bend-a-beet"/);
assert.match(coreHome, /href="\/core\/bendio-3d-land"/);
assert.match(coreHome, /href="\/core\/bendy-birds"/);
assert.match(coreHome, /href="\/core\/bend-fishing"/);
assert.match(coreHome, /href="\/core\/bend-aquarium"/);
assert.match(coreHome, /href="\/core\/bend-landscape"/);
assert.match(coreHome, /Same site and port/);
assert.match(coreHome, /6 theorems · 78 certificates/);
assert.match(coreHome, /4 theorems · 119 certificates/);
assert.match(coreHome, /20 theorems · 35 certificates/);
assert.match(coreHome, /5 theorems · 4 certificates/);
assert.match(coreHome, /10 theorems · 4 certificates/);
assert.match(coreHome, /8 theorems · 5 certificates/);
assert.match(coreHome, /12 theorems · 6 certificates/);
assert.match(corePoker, /href="\/poker"/);
assert.match(corePoker, /Bend2 Core · pure simulation/);
assert.match(corePoker, /id="proof-title"/);
for (const [index, match] of [...corePoker.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].entries()) {
  new vm.Script(match[1], { filename: `core-poker-${index}.js` });
}
const corePokerContext = { globalThis: {} };
vm.runInNewContext(coreData, corePokerContext, { filename: "core-poker-data.js" });
assert.equal(corePokerContext.globalThis.BEND2_POKER_DATA.$2.$, "PokerVerificationAudit");
assert.equal(corePokerContext.globalThis.BEND2_POKER_DATA.$2.$6, 78);
assert.equal(corePokerContext.globalThis.BEND2_POKER_DATA.$2.$7, 6);
assert.match(coreBelote, /href="\/belote"/);
assert.match(coreBelote, /Bend2 Core · four AIs/);
for (const [index, match] of [...coreBelote.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].entries()) {
  new vm.Script(match[1], { filename: `core-belote-${index}.js` });
}
const coreBeloteContext = { globalThis: {} };
vm.runInNewContext(coreBeloteData, coreBeloteContext, { filename: "core-belote-data.js" });
assert.equal(coreBeloteContext.globalThis.BEND2_BELOTE_DATA.$11.$, "BeloteVerificationAudit");
assert.equal(coreBeloteContext.globalThis.BEND2_BELOTE_DATA.$11.$6, 119);
assert.equal(coreBeloteContext.globalThis.BEND2_BELOTE_DATA.$11.$7, 4);
assert.match(coreBeet, /Bend-a-Beet/);
assert.match(coreBeet, /20 general theorems · 35 closed certificates/);
assert.match(coreBeet, /src="bend_a_beet_camera\.js"/);
assert.match(coreBeet, /function ellipsoid/);
assert.match(coreBeet, /function tube/);
assert.match(coreBeet, /function fur/);
assert.match(coreBeet, /function responseCable/);
assert.match(coreBeet, /function beetBody/);
assert.match(coreBeet, /function rootNetwork/);
assert.match(coreBeet, /function serratedLeaf/);
assert.match(coreBeet, /uShine/);
assert.match(coreBeet, /uReflection/);
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
let engineProfileCount = 0, engineProfiles = coreBeetContext.globalThis.BEND_A_BEET_DATA.$8;
while (engineProfiles?.$ === "Con") { engineProfileCount++; engineProfiles = engineProfiles.$1; }
assert.equal(engineProfileCount, 24);
let beetFrameCount = 0, beetFrames = coreBeetContext.globalThis.BEND_A_BEET_DATA.$9;
while (beetFrames?.$ === "Con") { beetFrameCount++; beetFrames = beetFrames.$1; }
assert.equal(beetFrameCount, 1086);

assert.match(coreBendio, /Bendio 3D Land/);
assert.match(coreBendio, /5 universal proofs · 4 certificates/);
assert.match(coreBendio, /BEND_ENGINE_WEBGL/);
assert.match(coreBendio, /function makeMesh/);
assert.match(coreBendio, /E\.part\("island"/);
checkInlineScripts(coreBendio, "core-bendio");
const bendioContext = { globalThis: {} };
vm.runInNewContext(coreBendioData, bendioContext, { filename: "core-bendio-data.js" });
const bendio = bendioContext.globalThis.BENDIO_DATA;
assert.equal(bendio.$, "Report");
assert.equal(listLength(bendio.$2), 18);
assert.equal(listLength(bendio.$3), 17);
assert.equal(bendio.$4, 18n);
assert.equal(bendio.$5, 612n);
assert.equal(bendio.$6, 5);

assert.match(coreBirds, /Bendy Birds/);
assert.match(coreBirds, /10 universal proofs · 4 certificates/);
assert.match(coreBirds, /BEND_ENGINE_WEBGL/);
assert.match(coreBirds, /function makeMesh/);
assert.match(coreBirds, /i % 2 \? "shard" : "star"/);
checkInlineScripts(coreBirds, "core-bendy-birds");
const birdsContext = { globalThis: {} };
vm.runInNewContext(coreBirdsData, birdsContext, { filename: "core-bendy-birds-data.js" });
vm.runInNewContext(coreBirdsResult, birdsContext, { filename: "core-bendy-birds-result.js" });
const birds = birdsContext.globalThis.BENDY_BIRDS_DATA;
assert.equal(birds.$, "Report");
assert.equal(listLength(birds.$1), 6);
assert.equal(listLength(birds.$2), 7);
assert.equal(listLength(birds.$3), 6);
assert.equal(birdsContext.globalThis.BENDY_BIRDS_AUX_RESULT.$, "Bendy.ShotResult");

assert.match(coreFishing, /Bend Fishing/);
assert.match(coreFishing, /8 universal proofs · 5 certificates/);
assert.match(coreFishing, /BEND_ENGINE_WEBGL/);
assert.match(coreFishing, /function makeMesh/);
assert.match(coreFishing, /E\.fish\(/);
checkInlineScripts(coreFishing, "core-bend-fishing");
const fishingContext = { globalThis: {} };
vm.runInNewContext(coreFishingData, fishingContext, { filename: "core-bend-fishing-data.js" });
const fishing = fishingContext.globalThis.BEND_FISHING_DATA;
assert.equal(fishing.$, "FishingReport");
assert.equal(listLength(fishing.$1), 1);
const fishingSpot = fishing.$1.$0;
assert.equal(listLength(fishingSpot.$1), 7);
assert.equal(listLength(fishingSpot.$2), 120);
assert.equal(listLength(fishingSpot.$3), 5);

assert.match(coreAquarium, /Bend Aquarium/);
assert.match(coreAquarium, /8 universal proofs · 5 certificates/);
assert.match(coreAquarium, /BEND_ENGINE_WEBGL/);
assert.match(coreAquarium, /function makeMesh/);
assert.match(coreAquarium, /E\.coral\(/);
checkInlineScripts(coreAquarium, "core-bend-aquarium");
const aquariumContext = { globalThis: {} };
vm.runInNewContext(coreAquariumData, aquariumContext, { filename: "core-bend-aquarium-data.js" });
const aquarium = aquariumContext.globalThis.BEND_AQUARIUM_DATA;
assert.equal(aquarium.$, "AquariumReport");
assert.equal(listLength(aquarium.$2), 12);
assert.equal(listLength(aquarium.$3), 12);
assert.equal(listLength(aquarium.$5), 360);
assert.equal(aquarium.$6, 360n);

assert.match(coreLandscape, /Bend Landscape/);
assert.match(coreLandscape, /12 UNIVERSAL PROOFS · 6 CERTIFICATES/);
assert.match(coreLandscape, /BEND_ENGINE_WEBGL/);
assert.match(coreLandscape, /function makeMesh/);
assert.match(coreLandscape, /E\.whale\(/);
checkInlineScripts(coreLandscape, "core-bend-landscape");
const landscapeContext = { globalThis: {} };
vm.runInNewContext(coreLandscapeData, landscapeContext, { filename: "core-landscape-data.js" });
const landscape = landscapeContext.globalThis.BEND_LANDSCAPE_DATA;
const landscapeCore = landscapeContext.globalThis.BEND_LANDSCAPE_DATA_CORE;
assert.equal(landscape.$, "LandscapeReport");
assert.equal(landscape.$3, 12);
assert.equal(landscape.$4, 6);
let boundary = landscapeCore.initial(731);
for (let index = 0; index < 24; index++) {
  const step = landscapeCore.next(731, index, boundary);
  assert.equal(step.$0.$1, index);
  assert.equal(step.$0.$2, index * 900);
  boundary = step.$1;
}
console.log("BendJogos browser-client checks passed.");
