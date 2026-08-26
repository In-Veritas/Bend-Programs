#!/usr/bin/env bun
import { readFileSync } from "node:fs";
import { join } from "node:path";
import vm from "node:vm";
import { packageContext, list, verifyCoreEntries } from "../Bend Engine/test_helpers.mjs";

const ctx = packageContext(import.meta.url);
const generated = readFileSync(join(ctx.here, "landscape_data.js"), "utf8");
const sandbox = { globalThis: {} };
vm.runInNewContext(generated, sandbox, { filename: "landscape_data.js" });
const report = sandbox.globalThis.BEND_LANDSCAPE_DATA;
const Core = sandbox.globalThis.BEND_LANDSCAPE_DATA_CORE;
const tag = value => value?.$;
const sameBoundary = (left, right) => Array.from({ length: 6 }, (_, index) => tag(left[`$${index}`])).every((value, index) => value === tag(right[`$${index}`]));
const tideY = value => Number(value.$7.$6);
const terrainY = { TerrainShore: 220, TerrainDune: 238, TerrainMeadow: 256, TerrainRise: 274, TerrainHill: 292, TerrainDescent: 256 };
const sandCount = value => Number(value.$0);
const schoolCount = value => Number(value.$0);
const partyCount = value => Number(value.$1);
const emergencePercent = value => Number(value.$0);
const spoutVolume = value => Number(value.$1);

if (report.$ !== "LandscapeReport" || Number(report.$3) !== 12 || Number(report.$4) !== 6) throw new Error("landscape report/proof metadata mismatch");
if (!Core || typeof Core.initial !== "function" || typeof Core.next !== "function") throw new Error("generated Core continuation functions are absent");

const key = 731, chunks = [];
let boundary = Core.initial(key);
for (let index = 0; index < 42; index++) {
  const input = boundary, step = Core.next(key, index, input), chunk = step.$0;
  if (tag(step) !== "ChunkStep" || tag(chunk) !== "LandscapeChunk") throw new Error(`bad chunk at ${index}`);
  if (Number(chunk.$1) !== index || Number(chunk.$2) !== index * 900) throw new Error(`non-monotonic chunk geometry at ${index}`);
  if (!sameBoundary(chunk.$3, input)) throw new Error(`chunk ${index} did not preserve its input boundary`);
  const sea = chunk.$4, land = chunk.$5, sky = chunk.$6, weather = chunk.$7, placement = chunk.$8;
  const whales = list(sea.$2), rocks = list(sea.$3), fish = list(sea.$4), schools = list(sea.$5), trees = list(land.$1), hills = list(land.$2), birds = list(sky.$0), clouds = list(sky.$1);
  if (whales.length !== 2 || rocks.length !== 3 || fish.length !== 5 || schools.length !== 2 || trees.length !== 5 || hills.length !== 3 || clouds.length !== 3) throw new Error(`entity cardinality changed at ${index}`);
  if (![2, 4].includes(birds.length) || partyCount(land.$3) < 1 || partyCount(land.$3) > 3 || list(land.$3.$0).length !== partyCount(land.$3)) throw new Error(`party/bird cardinality invalid at ${index}`);
  if (!(sandCount(sea.$1) >= 1 && sandCount(sea.$1) <= 5)) throw new Error(`sand bound invalid at ${index}`);
  for (const whale of whales) if (emergencePercent(whale.$3) > 30 || spoutVolume(whale.$4) > 110) throw new Error(`whale physical bound invalid at ${index}`);
  for (const school of schools) if (schoolCount(school.$2) < 4 || schoolCount(school.$2) > 12 || list(school.$3).length !== schoolCount(school.$2)) throw new Error(`school constructive cardinality invalid at ${index}`);
  if (Number(placement.$3) < 54 || Number(placement.$0) < 1 || Number(placement.$1) < 1 || Number(placement.$2) < 1) throw new Error(`placement spacing invalid at ${index}`);
  chunks.push(chunk); boundary = step.$1;
}
let tideFell = false;
for (let index = 1; index < chunks.length; index++) {
  const tideDelta = Math.abs(tideY(chunks[index]) - tideY(chunks[index - 1]));
  const terrainDelta = Math.abs(terrainY[tag(chunks[index].$5.$0)] - terrainY[tag(chunks[index - 1].$5.$0)]);
  if (tideDelta > 12 || terrainDelta > 36) throw new Error(`soft continuity bound failed between chunks ${index - 1}/${index}`);
  tideFell ||= tideY(chunks[index]) < tideY(chunks[index - 1]);
}
if (!tideFell || chunks.at(-1).$1 < 40n) throw new Error("long scrolling trace did not advance/fall");

const colors = new Map();
for (let residue = 0; residue < 16; residue++) {
  const first = Core.next(residue, 0, Core.initial(residue)).$0.$4.$2.$0.$1.$;
  colors.set(first, (colors.get(first) || 0) + 1);
}
for (const [name, expected] of [["WhaleGrey", 6], ["WhaleSlateBlue", 4], ["WhaleOceanBlue", 4], ["WhaleWhiteMorph", 1], ["WhaleBlackMorph", 1]]) if (colors.get(name) !== expected) throw new Error(`whale histogram ${name}: expected ${expected}, got ${colors.get(name)}`);

const different = Core.next(19, 73, Core.initial(19)).$0;
if (Number(different.$1) !== 73 || Number(different.$2) !== 65700) throw new Error("arbitrary distant Core continuation failed");
const viewer = readFileSync(join(ctx.here, "landscape_viewer.js"), "utf8"), html = readFileSync(join(ctx.here, "index.html"), "utf8"), readme = readFileSync(join(ctx.here, "README.md"), "utf8");
new Function(viewer);
for (const token of ["Core.next(key, nextIndex, boundary)", "addWhales", "addFish", "addTrees", "addBirds", "addClouds", "Core-selected bird calls"]) if (!viewer.includes(token)) throw new Error(`viewer misses ${token}`);
for (const token of ["E.whale(", "E.tree(", "E.character(", "E.wildBird(", "E.cloud(", "E.segment(", "E.part(\"island\"", "E.part(shape === \"SeaRockSharp\" ? \"shard\""]) if (!viewer.includes(token)) throw new Error(`viewer misses complex visual ${token}`);
for (const token of ["12 UNIVERSAL PROOFS", "Every rendered chunk", "three deep sectors", "Enable Core bird calls"]) if (!html.includes(token)) throw new Error(`page misses ${token}`);
for (const token of ["Approaches that did not work", "not Bend bugs", "structural induction", "6/4/4/1/1"]) if (!readme.includes(token)) throw new Error(`README misses ${token}`);
verifyCoreEntries(ctx, ["landscape_test.bend"]);
console.log("Bend Landscape verified: 42 continuous keyed chunks plus distant continuation, exact whale histogram, proof-carrying school members and bounded quantities, 12 universal proofs, 6 certificates, JS+C");
