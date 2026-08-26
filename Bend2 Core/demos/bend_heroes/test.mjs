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
const tag = value => value?.$;
const number = value => Number(value || 0);
const hero = (game, side = tag(game.$2)) => (side === "Blue" ? game.$4 : game.$3).$1;
const resources = (game, side = tag(game.$2)) => (side === "Blue" ? game.$4 : game.$3).$0;
const town = (game, side = tag(game.$2)) => (side === "Blue" ? game.$4 : game.$3).$2;
const slots = army => Array.from({ length: 7 }, (_, index) => army[`$${index}`]);
const firstOccupied = army => slots(army).findIndex(stack => tag(stack) === "Troop");
const command = (game, code, a = 0, b = 0) => Core.step(game, code, a, b);

if (tag(initial) !== "Game" || tag(initial.$2) !== "Red" || tag(initial.$6) !== "Adventure") throw new Error("initial Core state shape mismatch");
if (!Core || typeof Core.newGame !== "function" || typeof Core.step !== "function" || typeof Core.cell !== "function" || typeof Core.damageProbe !== "function") throw new Error("generated Core state functions are absent");

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

let exchanges = 0;
while (tag(game.$6) === "Combat" && exchanges++ < 80) {
  const own = firstOccupied(hero(game).$11), enemy = firstOccupied(game.$6.$0.$2);
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
  const own = firstOccupied(ownArmy), enemy = firstOccupied(enemyArmy);
  if (own < 0 || enemy < 0) break;
  const mana = number(hero(game).$8);
  game = command(game, mana >= 5 ? 22 : 20, own, enemy);
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
for (const token of ["state = Core.step(state, command, arg0, arg1)", "Core.newGame", "Core.cell", "localStorage", "buildAdventureScene", "buildCombatScene", "BEND_ENGINE_WEBGL"] ) if (!viewer.includes(token)) throw new Error(`viewer misses ${token}`);
for (const token of ["Bend2 Core · Bend Engine", "bend_engine_webgl.js", "BEND ENGINE", "three-dimensional Heroes scene"] ) if (!html.includes(token)) throw new Error(`page misses ${token}`);
for (const token of ["globalThis.BEND_ENGINE_WEBGL", "WebGL2 is required", "registerMesh", "bindOrbit"] ) if (!engine.includes(token)) throw new Error(`engine boundary misses ${token}`);

verifyCoreEntries(ctx, ["heroes.bend", "heroes_ranged_law_test.bend"]);
console.log(`Bend Heroes verified: 63 Core map cells, first-unit HP, economy/recruitment/day cycle, ${exchanges} guardian exchanges, ${siegeRounds} siege exchanges, deterministic feedback state, Bend Engine boundary, JS+C`);
