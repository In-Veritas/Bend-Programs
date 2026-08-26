#!/usr/bin/env bun
import { copyFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { buildBrowser } from "../Bend Engine/browser_build.mjs";

const here = dirname(fileURLToPath(import.meta.url));

// Keep the browser package self-contained while using the repository's shared
// renderer verbatim. This file is presentation only; Core still owns state.
copyFileSync(
  resolve(here, "../Bend Engine/bend_engine_webgl.js"),
  resolve(here, "bend_engine_webgl.js")
);

buildBrowser({
  moduleUrl: import.meta.url,
  source: "heroes.bend",
  target: "heroes_data.js",
  globalName: "BEND_HEROES_DATA",
  metadata: {
    browserCoreTransitions: true,
    presentation: "bend-engine-webgl2",
    engineRenderer: "Bend Engine/bend_engine_webgl.js",
    factions: ["Castle", "Necropolis"],
    map: [9, 7]
  },
  runtimeExports: {
    newGame: {
      emitted: "$heroes_initial_func$",
      bend: "heroes_initial_func",
      sample: ["1337"],
      returns: "Game"
    },
    step: {
      emitted: "$heroes_browser_step_func$",
      bend: "heroes_browser_step_func",
      sample: ["heroes_initial_func(1337)", "0", "0", "0"],
      returns: "Game"
    },
    cell: {
      emitted: "$heroes_cell_func$",
      bend: "heroes_cell_func",
      sample: ["0", "0"],
      returns: "Cell"
    },
    damageProbe: {
      emitted: "$heroes_damage_probe_func$",
      bend: "heroes_damage_probe_func",
      sample: ["4"],
      returns: "StackDamage"
    }
  }
});
