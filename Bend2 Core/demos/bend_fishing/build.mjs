#!/usr/bin/env bun
import { buildBrowser } from "../Bend Engine/browser_build.mjs";
buildBrowser({
  moduleUrl: import.meta.url,
  source: "bend_fishing.bend",
  target: "bend_fishing_data.js",
  globalName: "BEND_FISHING_DATA",
  metadata: { browserCoreTransitions: true, timingBranches: 5, waitingFrames: 120, reelFrames: 48 },
  runtimeExports: {
    session: { emitted: "$fishing_session_func$", bend: "fishing_session_func", sample: ["731", "600", "420"], returns: "FishingSession" },
    reel: { emitted: "$fishing_reel_func$", bend: "fishing_reel_func", sample: ["fishing_session_func(731, 600, 420)", "44"], returns: "ReelReport" }
  }
});
