#!/usr/bin/env bun
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { packageContext, loadData, list, verifyCoreEntries } from "../Bend Engine/test_helpers.mjs";

const ctx = packageContext(import.meta.url);
const raw = loadData(ctx.here, "bendio_data.js", "BENDIO_DATA");
const platforms = list(raw.$2), segments = list(raw.$3);
const frames = segments.flatMap(segment => list(segment.$4));
const html = readFileSync(join(ctx.here, "index.html"), "utf8");
const viewer = readFileSync(join(ctx.here, "bendio_viewer.js"), "utf8");
const generated = readFileSync(join(ctx.here, "bendio_data.js"), "utf8");

if (raw.$ !== "Report" || platforms.length !== 18 || segments.length !== 17 || frames.length !== 612) throw new Error("Bendio procedural report shape mismatch");
if (Number(raw.$4) !== 18 || Number(raw.$5) !== 612 || Number(raw.$6) !== 5) throw new Error("Bendio report declarations mismatch");
if (new Set(platforms.map(platform => platform.$7.$)).size < 5) throw new Error("Bendio seed lacks material variety");
for (let i = 0; i < segments.length; i++) {
  const segment = segments[i], local = list(segment.$4), first = local[0], last = local.at(-1);
  if (local.length !== 36) throw new Error(`segment ${i} does not contain 36 certified frames`);
  for (const axis of [1, 2, 3]) {
    if (Number(first[`$${axis}`]) !== Number(segment.$2[`$${axis - 1}`])) throw new Error(`segment ${i} takeoff mismatch`);
    if (Number(last[`$${axis}`]) !== Number(segment.$3[`$${axis - 1}`])) throw new Error(`segment ${i} landing mismatch`);
  }
  if (Number(segment.$5) < 610 || Number(segment.$5) > 779) throw new Error(`segment ${i} gap escaped generator range`);
  if (i + 1 < segments.length) for (const axis of [0, 1, 2]) if (Number(segment.$3[`$${axis}`]) !== Number(segments[i + 1].$2[`$${axis}`])) throw new Error(`segment ${i} does not join its successor`);
}
for (const token of ["Generate in Core", "director", "chase", "side", "first", "orbit"]) if (!html.includes(token)) throw new Error(`missing Bendio UI contract ${token}`);
for (const token of ["Core.level(seed)", "segments.flatMap", "index < frames.length - 1", "Replay level", "E.hero", "requestAnimationFrame"]) if (!viewer.includes(token)) throw new Error(`missing Bendio viewer contract ${token}`);
for (const token of ["E.part(\"island\"", "E.tree(", "E.part(\"arch\"", "E.part(\"crystal\"", "E.part(\"torus\"", "E.part(\"star\""]) if (!viewer.includes(token)) throw new Error(`missing Bendio complex visual ${token}`);
if (!generated.includes("globalThis.BENDIO_DATA_CORE") || !generated.includes("$bendio_report_seed_func$")) throw new Error("generated Core level function is not browser-exported");
new Function(viewer);
verifyCoreEntries(ctx, ["bendio_test.bend"]);
console.log("Bendio 3D Land verified: keyed 18-platform/17-jump level, 612 non-looping frames, 5 universal proofs, 4 certificates, JS+C");
