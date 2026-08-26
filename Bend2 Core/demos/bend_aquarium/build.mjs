#!/usr/bin/env bun
import { buildBrowser } from "../Bend Engine/browser_build.mjs";
buildBrowser({
  moduleUrl: import.meta.url,
  source: "bend_aquarium.bend",
  target: "bend_aquarium_data.js",
  globalName: "BEND_AQUARIUM_DATA",
  metadata: { visualizer: true, coralSpecies: 8, fixtureFrames: 360, unboundedCoreFrames: true },
  runtimeExports: {
    frame: { emitted: "$aquarium_frame_at_func$", bend: "aquarium_frame_at_func", sample: ["0", "91"], returns: "AquariumFrame" }
  }
});
