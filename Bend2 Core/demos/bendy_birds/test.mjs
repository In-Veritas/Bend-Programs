#!/usr/bin/env bun
import { readFileSync } from "node:fs";
import { join } from "node:path";
import vm from "node:vm";
import { packageContext, list, verifyCoreEntries } from "../Bend Engine/test_helpers.mjs";

const ctx = packageContext(import.meta.url), context = { globalThis: {} };
const generated = readFileSync(join(ctx.here, "bendy_birds_data.js"), "utf8");
vm.runInNewContext(generated, context, { filename: "bendy_birds_data.js" });
const raw = context.globalThis.BENDY_BIRDS_DATA, Core = context.globalThis.BENDY_BIRDS_DATA_CORE;
const birds = list(raw.$1), blocks = list(raw.$2), previews = list(raw.$3);
const html = readFileSync(join(ctx.here, "index.html"), "utf8"), viewer = readFileSync(join(ctx.here, "bendy_birds_viewer.js"), "utf8");
if (raw.$ !== "Report" || birds.length !== 6 || blocks.length !== 7 || previews.length !== 6) throw new Error("Bendy Birds report shape mismatch");
if (previews.some(shot => list(shot.$3).length !== 97) || new Set(birds.map(bird => bird.$0.$)).size !== 6 || new Set(blocks.map(block => block.$1.$)).size !== 7) throw new Error("Bendy Birds material/trajectory coverage mismatch");
const low = Core.shot(0, 18, 2, raw.$2, 0), high = Core.shot(0, 67, 2, raw.$2, 0), strong = Core.shot(3, 15, 4, raw.$2, 0);
const lowFrames = list(low.$3), highFrames = list(high.$3), strongFrames = list(strong.$3);
if (Number(low.$1) !== 18 || Number(high.$1) !== 67 || Number(strong.$2) !== 4) throw new Error("exact browser controls did not reach Core");
if (Number(lowFrames.at(-1).$1) === Number(highFrames.at(-1).$1)) throw new Error("angle does not alter the Core terminal x");
if (Math.max(...lowFrames.map(frame => Number(frame.$2))) >= Math.max(...highFrames.map(frame => Number(frame.$2)))) throw new Error("higher angle does not produce a higher Core arc");
for (const frames of [lowFrames, highFrames, strongFrames]) if (Number(frames[0].$2) !== 120 || Number(frames.at(-1).$2) !== 120) throw new Error("trajectory endpoint law failed in generated runtime");
if (list(strong.$4).every(block => block.$7.$ === "Standing")) throw new Error("strong localized impact damaged no block");
for (const token of ["jello", "rubber", "furball", "stone", "bubble", "spring", "Live Core transition", "Power"]) if (!html.includes(token)) throw new Error(`missing Bendy Birds feature ${token}`);
for (const token of ["Core.shot(code, angle, strength, currentBlocks, shotNumber)", "currentBlocks = chosen.rawBlocks", "index >= chosen.frames.length", "E.bird"]) if (!viewer.includes(token)) throw new Error(`missing interactive Core contract ${token}`);
for (const token of ["debrisKind", "E.part(\"bevel\"", "E.part(\"branch\"", "E.part(\"crystal\"", "E.tree(", "E.part(i % 3 ? \"star\" : \"torus\"", "i % 2 ? \"shard\" : \"star\""]) if (!viewer.includes(token)) throw new Error(`missing Bendy Birds complex visual ${token}`);
if (!generated.includes("globalThis.BENDY_BIRDS_DATA_CORE")) throw new Error("generated shot transition is not exported");
new Function(viewer);
verifyCoreEntries(ctx, ["bendy_birds_test.bend"]);
console.log("Bendy Birds verified: exact live angle/power Core transitions, persistent localized destruction, 97-frame non-looping shots, 10 universal proofs, 4 certificates, JS+C");
