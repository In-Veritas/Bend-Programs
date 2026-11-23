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
    factions: ["Castle", "Necropolis", "Inferno"],
    map: [9, 7]
  },
  runtimeExports: {
    newGame: {
      emitted: "$heroes_initial_func$",
      bend: "heroes_initial_func",
      sample: ["1337"],
      returns: "Game"
    },
    newScenario: {
      emitted: "$heroes_initial_faction_func$",
      bend: "heroes_initial_faction_func",
      sample: ["1337", "2"],
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
    },
    battleObstacle: {
      emitted: "$heroes_battle_obstacle_func$",
      bend: "heroes_battle_obstacle_func",
      sample: ["7", "5", "1337"],
      returns: "Bool"
    },
    battlefieldNew: {
      emitted: "$heroes_battlefield_new_func$",
      bend: "heroes_battlefield_new_func",
      sample: ["0"],
      returns: "Tactics.Battlefield"
    },
    hexDistance: {
      emitted: "$heroes_hex_distance_func$",
      bend: "heroes_hex_distance_func",
      sample: ["1", "5", "13", "5"],
      returns: "U32"
    },
    attackReach: {
      emitted: "$heroes_attack_reach_func$",
      bend: "heroes_attack_reach_func",
      sample: ["Archer{}", "1", "5", "13", "5", "False{}"],
      returns: "Tactics.AttackReach"
    },
    combatAi: {
      emitted: "$combat_ai_choice_func$",
      bend: "combat_ai_choice_func",
      sample: ["10", "red_army_func()", "blue_army_func()"],
      returns: "CombatAiChoice"
    },
    combatAiBattle: {
      emitted: "$combat_ai_battle_func$",
      bend: "combat_ai_battle_func",
      sample: ["0", "red_army_func()", "blue_army_func()", "Tactics.battlefield_new(0)"],
      returns: "CombatAiChoice"
    }
  }
});
