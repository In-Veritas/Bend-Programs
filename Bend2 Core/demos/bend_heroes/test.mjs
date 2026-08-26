#!/usr/bin/env bun
import { readFileSync } from "node:fs";
import { join } from "node:path";
import vm from "node:vm";
import { packageContext, verifyCoreEntries } from "../Bend Engine/test_helpers.mjs";

const ctx = packageContext(import.meta.url);
const generated = readFileSync(join(ctx.here, "heroes_data.js"), "utf8");
const engine = readFileSync(join(ctx.here, "bend_engine_webgl.js"), "utf8");
const sandbox = { globalThis: {} };
vm.runInNewContext(generated, sandbox, { filename: "heroes_data.js" });
const initial = sandbox.globalThis.BEND_HEROES_DATA;
const Core = sandbox.globalThis.BEND_HEROES_DATA_CORE;
const tag = value => value?.$?.split(".").pop();
const number = value => Number(value || 0);
const hero = (game, side = tag(game.$2)) => (side === "Blue" ? game.$4 : game.$3).$1;
const resources = (game, side = tag(game.$2)) => (side === "Blue" ? game.$4 : game.$3).$0;
const town = (game, side = tag(game.$2)) => (side === "Blue" ? game.$4 : game.$3).$2;
const slots = army => Array.from({ length: 7 }, (_, index) => army[`$${index}`]);
const firstOccupied = army => slots(army).findIndex(stack => tag(stack) === "Troop");
const command = (game, code, a = 0, b = 0) => Core.step(game, code, a, b);

if (tag(initial) !== "Game" || tag(initial.$2) !== "Red" || tag(initial.$6) !== "Adventure") throw new Error("initial Core state shape mismatch");
if (!Core || typeof Core.newGame !== "function" || typeof Core.newScenario !== "function" || typeof Core.step !== "function" || typeof Core.cell !== "function" || typeof Core.damageProbe !== "function" || typeof Core.battleObstacle !== "function" || typeof Core.battlefieldNew !== "function" || typeof Core.hexDistance !== "function" || typeof Core.attackReach !== "function" || typeof Core.combatAi !== "function" || typeof Core.combatAiBattle !== "function") throw new Error("generated Core state functions are absent");

for (const [index, player, opponent] of [[0, "Castle", "Necropolis"], [1, "Necropolis", "Inferno"], [2, "Inferno", "Castle"]]) {
  const scenario = Core.newScenario(41, index);
  if (tag(scenario.$3.$2.$0) !== player || tag(scenario.$4.$2.$0) !== opponent) throw new Error(`faction scenario ${index} mismatch`);
  if (number(scenario.$3.$1.$1) !== 1 || number(scenario.$3.$1.$2) !== 5 || number(scenario.$4.$1.$1) !== 7 || number(scenario.$4.$1.$2) !== 1) throw new Error(`faction scenario ${index} home positions mismatch`);
}
const infernoRecruit = command(Core.newScenario(41, 2), 8, 1, 1);
if (tag(hero(infernoRecruit).$11.$0.$0) !== "Imp" || number(hero(infernoRecruit).$11.$0.$1) !== 46) throw new Error("playable Inferno recruitment mismatch");
const aiEconomy = command(Core.newScenario(5, 0), 30);
if (number(town(aiEconomy).$1) !== 2 || town(aiEconomy).$4 !== true) throw new Error("strategic AI did not invest at its home town before departing");
let redAiRoute = Core.newScenario(5, 1);
for (let step = 0; step < 6; step++) redAiRoute = command(redAiRoute, 30);
if (tag(redAiRoute.$6) !== "Combat" || tag(redAiRoute.$6.$0.$1) !== "GuardianBattle") throw new Error("Red strategic AI did not navigate the guarded route");
let blueAiRoute = command(Core.newScenario(5, 2), 4);
for (let step = 0; step < 6; step++) blueAiRoute = command(blueAiRoute, 30);
if (tag(blueAiRoute.$6) !== "Combat" || tag(blueAiRoute.$6.$0.$1) !== "GuardianBattle") throw new Error("Blue strategic AI did not navigate the guarded route");
const playWithCoreAi = faction => {
  let state = Core.newScenario(900 + faction, faction);
  for (let step = 0; step < 160 && tag(state.$6) !== "Victory"; step++) {
    if (tag(state.$6) === "Adventure") state = command(state, 30);
    else if (tag(state.$6) === "Combat") {
      const active = hero(state), battle = state.$6.$0;
      const choice = Core.combatAiBattle(active.$8, active.$11, battle.$2, battle.$4);
      state = command(state, number(choice.$0), number(choice.$1), number(choice.$2));
    }
  }
  return state;
};
for (let faction = 0; faction < 3; faction++) {
  const completed = playWithCoreAi(faction);
  if (tag(completed.$6) !== "Victory" || tag(completed.$6.$0) !== "Red") throw new Error(`Core AI did not complete faction scenario ${faction}`);
}

const initialArmy = hero(initial, "Red").$11;
const pikemanKind = initialArmy.$0.$0, archerKind = initialArmy.$1.$0;
if (number(Core.hexDistance(1, 5, 13, 5)) !== 12) throw new Error("hex battlefield distance mismatch");
if (tag(Core.attackReach(archerKind, 1, 5, 13, 5, false)) !== "RangedAttack") throw new Error("numeric Archer range did not permit a distant shot");
if (tag(Core.attackReach(pikemanKind, 1, 5, 13, 5, false)) !== "IllegalAttack") throw new Error("melee stack incorrectly attacked across the battlefield");
let obstacleCount = 0;
for (let row = 0; row < 11; row++) for (let column = 0; column < 15; column++) {
  const obstacle = Core.battleObstacle(column, row, 0);
  if ((column < 2 || column > 12) && obstacle) throw new Error("deployment column contains an obstacle");
  if (obstacle) obstacleCount++;
}
if (!obstacleCount) throw new Error("deterministic battlefield produced no interior obstacles");
const aiChoice = Core.combatAi(10, initialArmy, hero(initial, "Blue").$11);
if (tag(aiChoice) !== "CombatAiChoice" || number(aiChoice.$0) !== 22 || number(aiChoice.$1) !== 0 || number(aiChoice.$2) !== 2) throw new Error("Core combat AI did not choose spell/strongest attacker/weakest target");
const positionalAi = Core.combatAiBattle(0, initialArmy, hero(initial, "Blue").$11, Core.battlefieldNew(0));
if (number(positionalAi.$0) !== 24 || number(positionalAi.$1) !== 0) throw new Error("positional combat AI did not advance a distant melee stack");

const scratched = Core.damageProbe(4), oneLost = Core.damageProbe(12), destroyed = Core.damageProbe(30);
if (tag(scratched.$0) !== "Troop" || number(scratched.$0.$1) !== 3 || number(scratched.$0.$2) !== 6 || number(scratched.$1) !== 0) throw new Error("partial top-creature health was not preserved");
if (tag(oneLost.$0) !== "Troop" || number(oneLost.$0.$1) !== 2 || number(oneLost.$0.$2) !== 8 || number(oneLost.$1) !== 1) throw new Error("damage did not flow through first-unit HP into the stack");
if (tag(destroyed.$0) !== "EmptyStack" || number(destroyed.$1) !== 3) throw new Error("lethal stack damage mismatch");

const diagonal = command(Core.newGame(7), 9);
if (number(hero(diagonal).$1) !== 2 || number(hero(diagonal).$2) !== 4 || number(hero(diagonal).$3) !== 1459) throw new Error("141-percent diagonal movement mismatch");

let passable = 0, water = 0, sites = new Map();
for (let y = 0; y < 7; y++) for (let x = 0; x < 9; x++) {
  const cell = Core.cell(x, y);
  if (tag(cell) !== "Cell") throw new Error(`bad cell ${x},${y}`);
  if (cell.$3) passable++; else water++;
  sites.set(tag(cell.$1), (sites.get(tag(cell.$1)) || 0) + 1);
}
if (passable !== 58 || water !== 5) throw new Error(`map passability mismatch ${passable}/${water}`);
for (const site of ["RedTownSite", "BlueTownSite", "GoldPileSite", "WoodPileSite", "ShrineSite", "ArtifactSite", "SawmillSite", "GoldMineSite", "GuardianSite"]) {
  if (sites.get(site) !== 1) throw new Error(`expected exactly one ${site}`);
}

let game = Core.newGame(20260824);
const invalidTier = command(Core.newGame(99), 8, 0, 1);
if (number(resources(invalidTier).$0) !== 10000 || number(hero(invalidTier).$11.$6?.$1) !== 0) throw new Error("Core accepted an out-of-range recruitment tier");
const awayRecruitment = command(command(Core.newGame(99), 1), 8, 1, 1);
if (number(hero(awayRecruitment).$11.$0.$1) !== 30 || number(resources(awayRecruitment).$0) !== 11000) throw new Error("Core allowed field recruitment away from the home town");
game = command(game, 1);
if (number(hero(game).$1) !== 2 || number(hero(game).$2) !== 5 || number(resources(game).$0) !== 11000 || game.$5.$0 !== false) throw new Error("gold-pile movement transition mismatch");
game = command(game, 3);
game = command(game, 1);
if (number(resources(game).$0) !== 11000) throw new Error("one-shot map object paid twice");
game = command(game, 3);

game = command(game, 5);
if (number(town(game).$1) !== 2 || town(game).$4 !== true || number(resources(game).$0) !== 6000) throw new Error("hall construction mismatch");
const builtOnce = game;
game = command(game, 6);
if (number(town(game).$2) !== 0 || number(resources(game).$0) !== 6000) throw new Error("one-building-per-day rule failed");

game = command(game, 8, 1, 14);
game = command(game, 8, 2, 9);
if (number(hero(game).$11.$0.$1) !== 44 || number(hero(game).$11.$1.$1) !== 21) throw new Error("seven-slot recruitment merge mismatch");
if (number(town(game).$5.$0) !== 0 || number(town(game).$5.$1) !== 0) throw new Error("recruitment stock was not consumed");

game = command(game, 4);
if (tag(game.$2) !== "Blue" || number(game.$1) !== 1) throw new Error("Red-to-Blue turn handoff mismatch");
game = command(game, 4);
if (tag(game.$2) !== "Red" || number(game.$1) !== 2 || number(town(game).$1) !== 2 || town(game).$4 !== false) throw new Error("new-day reset mismatch");
if (number(resources(game).$0) !== number(resources(builtOnce).$0) - 1740 + 2000) throw new Error("daily hall income mismatch");

for (const move of [1, 1, 0, 0, 1]) game = command(game, move);
if (tag(game.$6) !== "Combat" || tag(game.$6.$0.$1) !== "GuardianBattle" || tag(game.$5.$4) !== "Red") throw new Error("mine capture or guardian combat transition mismatch");
const battlefield = game.$6.$0.$4;
if (tag(battlefield) !== "Battlefield" || tag(battlefield.$0.$0) !== "AtHex" || number(battlefield.$0.$0.$0) !== 1 || number(battlefield.$1.$0.$0) !== 13) throw new Error("combat did not retain Core-owned 15x11 deployment formations");

const distantMelee = command(game, 20, 0, 0);
if (number(distantMelee.$6.$0.$3) !== 1 || !String(distantMelee.$9).includes("rejected")) throw new Error("distant melee attack was not rejected by the tactical state");
game = command(game, 24, 0, 2 * 15 + 5);
if (number(game.$6.$0.$4.$0.$0.$0) !== 5 || number(game.$6.$0.$4.$0.$0.$1) !== 2) throw new Error("first legal battlefield move did not update the Core formation");
if (number(game.$6.$0.$4.$1.$0.$0) >= 13) throw new Error(`enemy tactical AI did not answer by advancing its melee stack (${number(game.$6.$0.$4.$1.$0.$0)})`);
game = command(game, 24, 0, 2 * 15 + 9);
game = command(game, 24, 0, 2 * 15 + 12);
if (number(game.$6.$0.$4.$0.$0.$0) !== 12) throw new Error("melee stack did not approach its target across the hex grid");
const beforeMeleeCount = number(game.$6.$0.$2.$0.$1);
game = command(game, 20, 0, 0);
if (number(game.$6.$0.$2.$0.$1) >= beforeMeleeCount) throw new Error("adjacent melee attack did not damage its target");

let exchanges = 0;
while (tag(game.$6) === "Combat" && exchanges++ < 80) {
  const own = tag(hero(game).$11.$1) === "Troop" ? 1 : firstOccupied(hero(game).$11), enemy = firstOccupied(game.$6.$0.$2);
  if (own < 0 || enemy < 0) throw new Error("combat exposed an empty side without resolving");
  game = command(game, 20, own, enemy);
}
if (tag(game.$6) !== "Adventure" || exchanges >= 80 || !slots(game.$5.$6).every(stack => tag(stack) === "EmptyStack")) throw new Error("guardian battle did not resolve deterministically");
if (number(hero(game).$9) < 2 || number(hero(game).$10) < 1200) throw new Error("hero progression reward mismatch");

game = command(game, 1);
if (number(hero(game).$4) < 6 || game.$5.$3 !== false) throw new Error("artifact pickup did not update the Core hero");
for (const move of [1, 1, 0, 0]) game = command(game, move);
if (tag(game.$6) !== "Combat" || tag(game.$6.$0.$1) !== "EnemyTownBattle") throw new Error("enemy town assault did not begin");

let siegeRounds = 0;
while (tag(game.$6) === "Combat" && siegeRounds++ < 120) {
  const ownArmy = hero(game).$11, enemyArmy = game.$6.$0.$2;
  const own = tag(ownArmy.$1) === "Troop" ? 1 : firstOccupied(ownArmy), enemy = firstOccupied(enemyArmy);
  if (own < 0 || enemy < 0) break;
  const mana = number(hero(game).$8);
  game = command(game, mana >= 5 ? 22 : 20, own, enemy);
  if (tag(game.$6) === "Combat" && tag(game.$6.$0.$2[`$${enemy}`]) === "EmptyStack" && tag(game.$6.$0.$4.$1[`$${enemy}`]) !== "OffBattlefield") throw new Error("destroyed stack continued occupying a battlefield hex");
}
if (siegeRounds >= 120) throw new Error("town battle failed to terminate");
if (tag(game.$6) !== "Victory" || tag(game.$6.$0) !== "Red") throw new Error("a fully recruited Red campaign did not end in town-capture victory");

const deterministicA = Core.newGame(77), deterministicB = Core.newGame(77);
const trace = state => [1, 3, 1, 5, 8].reduce((value, code, index) => command(value, code, index === 4 ? 1 : 0, index === 4 ? 2 : 0), state);
if (JSON.stringify(trace(deterministicA)) !== JSON.stringify(trace(deterministicB))) throw new Error("equal seeds did not produce equal immutable traces");

const viewer = readFileSync(join(ctx.here, "heroes_viewer.js"), "utf8");
const html = readFileSync(join(ctx.here, "index.html"), "utf8");
new Function(viewer);
new Function(engine);
for (const token of ["state = Core.step(state, command, arg0, arg1)", "Core.newScenario", "Core.cell", "Core.combatAiBattle", "Core.battleObstacle", "combat-move", "ai-adventure", "localStorage", "buildAdventureScene", "buildCombatScene", "BEND_ENGINE_WEBGL"] ) if (!viewer.includes(token)) throw new Error(`viewer misses ${token}`);
for (const token of ["Bend2 Core · Bend Engine", "bend_engine_webgl.js", "BEND ENGINE", "three-dimensional Heroes scene"] ) if (!html.includes(token)) throw new Error(`page misses ${token}`);
for (const token of ["globalThis.BEND_ENGINE_WEBGL", "WebGL2 is required", "registerMesh", "bindOrbit"] ) if (!engine.includes(token)) throw new Error(`engine boundary misses ${token}`);

verifyCoreEntries(ctx, ["heroes.bend"]);
console.log(`Bend Heroes verified: 63 Core map cells, 165 battle hexes, 3 AI-completed faction scenarios, first-unit HP, economy/recruitment/day cycle, ${exchanges} guardian exchanges, ${siegeRounds} siege exchanges, deterministic feedback state, Bend Engine boundary, JS+C`);
