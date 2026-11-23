// Build the water_movement outputs from main.bend:
//
//   frames.json  the old "pure physics -> JSON" filmstrip: Wm.frames_json(),
//                called straight from the ES module `bend main.bend -o x.mjs`
//                writes (FRAMES snapshots, FRAME_STEP steps apart).
//   water.html   the live browser version: web/index.html bundled by
//                `bend web/index.html -o <dir>` and inlined into one file.
//
// Usage: bun build.mjs            (needs `bend` on PATH; run from anywhere)

import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const DIR = dirname(fileURLToPath(import.meta.url));
// A `bun` that is really the bend binary in bun mode marks its children with
// BUN_BE_BUN; drop it so the `bend` we call runs as bend.
const env = { ...process.env };
delete env.BUN_BE_BUN;
const run = (cmd, args) => execFileSync(cmd, args, { stdio: "inherit", env });
const tmp = mkdtempSync(join(tmpdir(), "water-"));
try {
  const mod = join(tmp, "water.mjs");
  run("bend", [join(DIR, "main.bend"), "-o", mod]);
  const W = (await import(mod)).default;
  const json = W["Wm.frames_json"]();
  JSON.parse(json); // validate
  writeFileSync(join(DIR, "frames.json"), json);
  console.log("wrote frames.json (" + json.length + " bytes)");

  const dist = join(tmp, "dist");
  run("bend", [join(DIR, "web", "index.html"), "-o", dist]);
  execFileSync(process.execPath, [join(DIR, "web", "inline.mjs"), dist,
    join(DIR, "water.html")], { stdio: "inherit" });
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
