#!/usr/bin/env bun
import { buildBrowser } from "../Bend Engine/browser_build.mjs";
buildBrowser({
  moduleUrl: import.meta.url,
  source: "bendio.bend",
  target: "bendio_data.js",
  globalName: "BENDIO_DATA",
  metadata: { npc: true, procedural: true, platforms: 18, segments: 17, frames: 612 },
  runtimeExports: {
    level: { emitted: "$bendio_report_seed_func$", bend: "bendio_report_seed_func", sample: ["7319"], returns: "Report" }
  }
});
