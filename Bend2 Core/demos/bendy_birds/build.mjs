#!/usr/bin/env bun
import { buildBrowser } from "../Bend Engine/browser_build.mjs";
buildBrowser({
  moduleUrl: import.meta.url,
  source: "bendy_birds.bend",
  target: "bendy_birds_data.js",
  globalName: "BENDY_BIRDS_DATA",
  metadata: { browserCoreTransitions: true, previews: 6, framesPerShot: 97 },
  runtimeExports: {
    shot: {
      emitted: "$bendy_browser_shot_func$",
      bend: "bendy_browser_shot_func",
      sample: ["0", "28", "3", "bendy_blocks_func()", "0"],
      returns: "ShotResult"
    }
  }
});
