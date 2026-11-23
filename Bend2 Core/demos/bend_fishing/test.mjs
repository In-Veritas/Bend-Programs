#!/usr/bin/env bun
import { readFileSync } from "node:fs";
import { join } from "node:path";
import vm from "node:vm";
import { packageContext, list, verifyCoreEntries } from "../Bend Engine/test_helpers.mjs";

const ctx = packageContext(import.meta.url), source = readFileSync(join(ctx.here, "bend_fishing_data.js"), "utf8"), context = { globalThis: {} };
vm.runInNewContext(source, context, { filename: "bend_fishing_data.js" });
const Core = context.globalThis.BEND_FISHING_DATA_CORE;
const models = active => active.$ === "OneActiveFish" ? [active.$0] : [active.$0, active.$1];
const histogram = new Map();
for (let seed = 0; seed < 16; seed++) {
  const session = Core.session(seed, 520, 380), active = models(session.$3), waiting = list(session.$4);
  if (active.length < 1 || active.length > 2 || waiting.length !== 120) throw new Error(`session ${seed} violates active/frame cardinality`);
  const tag = active[0].$1.$; histogram.set(tag, (histogram.get(tag) || 0) + 1);
  for (let tick = Number(session.$5); tick <= Number(session.$6); tick++) if (waiting[tick].$3 !== 145) throw new Error(`session ${seed} has no exact visible bite cue at ${tick}`);
  const caught = Core.reel(session, Number(session.$5) + 2), early = Core.reel(session, 0);
  if (caught.$1.$ !== "Caught" || early.$1.$ !== "Escaped" || list(caught.$2).length !== 48 || list(early.$2).length !== 48) throw new Error(`session ${seed} timing/reel transition mismatch`);
  if (!list(caught.$2).every(frame => frame.$7 === true) || !list(early.$2).every(frame => frame.$7 === false)) throw new Error(`session ${seed} reel animation disagrees with result`);
}
const expected = { RiverBass: 3, GoldenKoi: 2, BlueTuna: 2, MoonJelly: 1, ReefShark: 1, RibbonEel: 2, PufferFish: 2, Coelacanth: 1, MantaRay: 1, Seahorse: 1 };
for (const [species, count] of Object.entries(expected)) if (histogram.get(species) !== count) throw new Error(`16-bucket distribution mismatch for ${species}`);
const viewer = readFileSync(join(ctx.here, "bend_fishing_viewer.js"), "utf8"), html = readFileSync(join(ctx.here, "index.html"), "utf8");
for (const token of ["Core.session(nextSeed, castX, castZ)", "Core.reel(session.raw, index)", "OneActiveFish", "caughtSpecies", "canvas.addEventListener(\"click\""] ) if (!viewer.includes(token)) throw new Error(`missing fishing interaction ${token}`);
for (const token of ["addLagoonDetails", "E.segment(\"branch\"", "E.part(\"leaf\"", "E.part(\"torus\"", "E.part(\"island\"", "E.part(\"star\""]) if (!viewer.includes(token)) throw new Error(`missing fishing complex visual ${token}`);
for (const token of ["Occult until the hook succeeds", "One or two, by type", "8 universal proofs", "16-slot species histogram"]) if (!html.includes(token)) throw new Error(`missing fishing contract ${token}`);
if (!source.includes("globalThis.BEND_FISHING_DATA_CORE")) throw new Error("generated session/reel functions are not exported");
new Function(viewer);
verifyCoreEntries(ctx, ["bend_fishing_test.bend"]);
console.log("Bend Fishing verified: click-position Core casts, 1–2 occult fish, exact 16-bucket distribution, bite-cued reel animation, 8 universal proofs, 5 certificates, JS+C");
