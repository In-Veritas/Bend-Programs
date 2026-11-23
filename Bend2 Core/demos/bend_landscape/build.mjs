#!/usr/bin/env bun
import { buildBrowser } from "../Bend Engine/browser_build.mjs";
buildBrowser({
  moduleUrl: import.meta.url,
  source: "landscape.bend",
  target: "landscape_data.js",
  globalName: "BEND_LANDSCAPE_DATA",
  metadata: { keyed: true, unboundedCoreChunks: true, sectors: ["sea", "land", "sky"] },
  runtimeExports: {
    initial: { emitted: "$landscape_initial_boundary_func$", bend: "landscape_initial_boundary_func", sample: ["731"], returns: "Boundary" },
    next: { emitted: "$landscape_next_chunk_func$", bend: "landscape_next_chunk_func", sample: ["731", "0", "landscape_initial_boundary_func(731)"], returns: "ChunkStep" }
  }
});
