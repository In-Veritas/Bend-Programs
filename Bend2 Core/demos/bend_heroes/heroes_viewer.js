(() => {
  "use strict";

  const E = globalThis.BEND_ENGINE_WEBGL;
  const Core = globalThis.BEND_HEROES_DATA_CORE;
  const initial = globalThis.BEND_HEROES_DATA;
  if (!E || !Core || !initial) throw new Error("Bend Heroes requires generated Core data and Bend Engine WebGL2");

  const $ = id => document.getElementById(id);
  const number = value => Number(value || 0);
  const tag = value => value?.$ || "Unknown";
  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
  const add = (left, right) => left.map((value, index) => value + right[index]);
  const sub = (left, right) => left.map((value, index) => value - right[index]);
  const dot = (left, right) => left[0] * right[0] + left[1] * right[1] + left[2] * right[2];
  const cross = (left, right) => [left[1] * right[2] - left[2] * right[1], left[2] * right[0] - left[0] * right[2], left[0] * right[1] - left[1] * right[0]];
  const norm = vector => { const length = Math.hypot(...vector) || 1; return vector.map(value => value / length); };
  const canvas = $("game");
  const renderer = E.create(canvas);
  const orbit = E.bindOrbit(canvas, { yaw: -.63, pitch: .77, distance: 16.2, target: [0, 0, 0] });

  const cells = Array.from({ length: 7 }, (_, y) => Array.from({ length: 9 }, (_, x) => Core.cell(x, y)));
  const creatureNames = {
    Pikeman: "Pikemen", Archer: "Archers", Griffin: "Griffins", Swordsman: "Swordsmen",
    Monk: "Monks", Cavalier: "Cavaliers", Angel: "Angels", Skeleton: "Skeletons",
    WalkingDead: "Walking Dead", Wight: "Wights", Vampire: "Vampires", Lich: "Liches",
    BlackKnight: "Black Knights", BoneDragon: "Bone Dragons"
  };
  const resourceNames = ["Gold", "Wood", "Ore", "Mercury", "Sulfur", "Crystal", "Gems"];
  const terrainStyle = {
    Grass: { color: "#527e3b", color2: "#8fa950", texture: 3, roughness: .95, y: .02 },
    Dirt: { color: "#76583e", color2: "#ad885b", texture: 3, roughness: .97, y: 0 },
    Rough: { color: "#777254", color2: "#a59b68", texture: 3, roughness: 1, y: .08 },
    Swamp: { color: "#354f38", color2: "#6d7940", texture: 6, roughness: .92, y: -.06 },
    Water: { color: "#175c78", color2: "#55b7bf", texture: 0, roughness: .06, y: -.12 },
    Rock: { color: "#4d4d49", color2: "#77746b", texture: 3, roughness: 1, y: .36 }
  };
  const siteLabels = {
    RedTownSite: "Castle", BlueTownSite: "Necropolis", GoldPileSite: "Gold pile", WoodPileSite: "Wood pile",
    ShrineSite: "Shrine", ArtifactSite: "Artifact", SawmillSite: "Sawmill", GoldMineSite: "Gold mine", GuardianSite: "Guardians"
  };
  const tierNames = {
    Castle: ["Pikeman", "Archer", "Griffin", "Swordsman", "Monk", "Cavalier", "Angel"],
    Necropolis: ["Skeleton", "Walking Dead", "Wight", "Vampire", "Lich", "Black Knight", "Bone Dragon"]
  };

  let state = initial;
  let history = [];
  let sceneMode = "map";
  let actionFx = null;
  let hotspotEntries = [];
  let previousFrame = performance.now();

  const mapPoint = (x, y, height = 0) => [(number(x) - 4) * 1.65, height, (number(y) - 3) * 1.5];
  const armySlots = army => Array.from({ length: 7 }, (_, index) => army[`$${index}`]);
  const stackText = stack => tag(stack) === "Troop" ? `${number(stack.$1)} ${creatureNames[tag(stack.$0)] || tag(stack.$0)}` : "Empty";
  const armyEmpty = army => armySlots(army).every(stack => tag(stack) === "EmptyStack");
  const kingdomFor = (game, owner) => owner === "Blue" ? game.$4 : game.$3;
  const activeKingdom = (game = state) => kingdomFor(game, tag(game.$2));
  const activeHero = (game = state) => activeKingdom(game).$1;

  function calendar(dayValue) {
    const value = Math.max(1, number(dayValue));
    return { month: Math.floor((value - 1) / 28) + 1, week: Math.floor(((value - 1) % 28) / 7) + 1, day: ((value - 1) % 7) + 1 };
  }

  function siteVisible(site, world = state.$5) {
    switch (tag(site)) {
      case "GoldPileSite": return world.$0;
      case "WoodPileSite": return world.$1;
      case "ShrineSite": return world.$2;
      case "ArtifactSite": return world.$3;
      case "GuardianSite": return !armyEmpty(world.$6);
      default: return tag(site) !== "EmptySite";
    }
  }

  function ownerColors(owner) {
    return owner === "Blue"
      ? { cloth: "#355d99", cloth2: "#172b50", accent: "#9ec6f0", dark: "#111827", flag: "#315f9d" }
      : { cloth: "#a43b31", cloth2: "#501d1b", accent: "#f1ce73", dark: "#302620", flag: "#a6352f" };
  }

  function shadow(out, position, sx = .7, sz = .45, alpha = .25) {
    out.push(E.part("disc", [position[0], .025, position[2]], [sx, .014, sz], "#07100a", { alpha, roughness: 1 }));
  }

  function flagParts(position, owner, scale = 1) {
    const color = ownerColors(owner).flag;
    return [
      E.part("cylinder", add(position, [0, .82 * scale, 0]), [.035 * scale, .84 * scale, .035 * scale], "#76573a", { roughness: .8 }),
      E.part("wing", add(position, [.2 * scale, 1.43 * scale, 0]), [.42 * scale, .28 * scale, .42 * scale], color, { rot: [0, -Math.PI / 2, Math.PI / 2], doubleSided: true, wind: .18, phase: owner === "Blue" ? 2 : 0 })
    ];
  }

  function castleParts(position, faction, scale = 1, hall = 1, fort = 0) {
    const necro = faction === "Necropolis";
    const stone = necro ? "#353947" : "#92918a";
    const dark = necro ? "#191d2a" : "#585a55";
    const roof = necro ? "#49325f" : "#355f8c";
    const glow = necro ? "#9a62d6" : "#f2d16b";
    const out = [];
    const at = offset => add(position, offset.map(value => value * scale));
    out.push(E.part("island", at([0, -.28, 0]), [2.2 * scale, .32 * scale, 1.75 * scale], necro ? "#30313b" : "#6e7754", { color2: dark, texture: 3, roughness: .98 }));
    out.push(E.part("bevel", at([0, .7, 0]), [1.05 * scale, .78 * scale, .82 * scale], stone, { color2: dark, texture: 7, roughness: .82 }));
    for (const side of [-1, 1]) for (const back of [-1, 1]) {
      const tower = at([side * 1.12, .82, back * .74]);
      out.push(E.part(necro ? "shard" : "cylinder", tower, [.38 * scale, .9 * scale, .38 * scale], side === back ? stone : dark, { roughness: .87, rot: [0, side * .22, 0] }));
      out.push(E.part("cone", at([side * 1.12, 1.85, back * .74]), [.48 * scale, .48 * scale, .48 * scale], roof, { roughness: .67 }));
    }
    out.push(E.part(necro ? "shard" : "bevel", at([0, 1.75, 0]), [.62 * scale, (1 + hall * .18) * scale, .56 * scale], dark, { color2: stone, texture: 7, roughness: .8 }));
    out.push(E.part("crystal", at([0, 2.9 + hall * .18, 0]), [.22 * scale, .36 * scale, .22 * scale], glow, { emissive: necro ? .34 : .12, rim: .25, pulse: .06 }));
    if (fort > 0) for (const z of [-1.05, 1.05]) out.push(E.part("bevel", at([0, .42, z]), [1.7 * scale, .43 * scale, .16 * scale], stone, { color2: dark, texture: 7, roughness: .9 }));
    if (fort > 1) for (const x of [-1.55, 1.55]) out.push(E.part("bevel", at([x, .42, 0]), [.16 * scale, .43 * scale, 1.12 * scale], stone, { color2: dark, texture: 7, roughness: .9 }));
    out.push(...flagParts(at([.1, 2.65 + hall * .18, 0]), necro ? "Blue" : "Red", .68 * scale));
    return out;
  }

  function sawmillParts(position, owner) {
    const out = [
      E.part("bevel", add(position, [0, .32, 0]), [.7, .35, .52], "#755136", { color2: "#3b2c21", texture: 2, roughness: .92 }),
      E.part("cone", add(position, [0, .82, 0]), [.82, .42, .72], "#4e5d32", { roughness: .94 }),
      E.part("torus", add(position, [.74, .4, 0]), [.43, .09, .43], "#9b7650", { rot: [Math.PI / 2, 0, 0], roughness: .72 })
    ];
    for (let index = 0; index < 5; index++) out.push(E.part("branch", add(position, [(.25 - index * .12), .08, .64 + index * .07]), [.09, .58, .09], "#754c2c", { rot: [Math.PI / 2, index * .11, Math.PI / 2], roughness: .96 }));
    if (owner !== "Neutral") out.push(...flagParts(add(position, [-.58, 0, -.34]), owner, .48));
    return out;
  }

  function mineParts(position, owner) {
    const out = [E.part("arch", add(position, [0, .55, 0]), [.9, .92, .72], "#4c4c48", { color2: "#252722", texture: 3, roughness: .98, rot: [0, Math.PI / 2, 0] })];
    for (let index = 0; index < 7; index++) out.push(E.part(index % 3 ? "rock" : "crystal", add(position, [Math.sin(index * 2.1) * .72, .12 + index % 2 * .09, Math.cos(index * 1.7) * .58]), [.18, .15 + index % 2 * .12, .18], index % 3 ? "#55564e" : "#d7a93b", { roughness: .72, metallic: index % 3 ? 0 : .55, rot: [index, index * .4, 0] }));
    if (owner !== "Neutral") out.push(...flagParts(add(position, [.62, 0, -.35]), owner, .48));
    return out;
  }

  function shrineParts(position) {
    const out = [E.part("disc", add(position, [0, .08, 0]), [.72, .12, .72], "#d8cfb1", { roughness: .7 })];
    for (const side of [-1, 1]) out.push(E.part("cylinder", add(position, [side * .45, .62, 0]), [.12, .58, .12], "#d6d0bd", { roughness: .65 }));
    out.push(E.part("arch", add(position, [0, 1.05, 0]), [.58, .72, .3], "#ded8c4", { roughness: .64 }), E.part("star", add(position, [0, 1.15, 0]), [.22, .06, .22], "#82c9ff", { emissive: .42, rim: .4, rot: [Math.PI / 2, 0, 0], pulse: .12 }));
    return out;
  }

  function guardianParts(position, time) {
    const out = [];
    for (const side of [-1, 1]) {
      const p = add(position, [side * .48, .78 + Math.sin(time * 1.7 + side) * .08, 0]);
      out.push(E.part("capsule", p, [.32, .62, .3], "#697484", { color2: "#272d3d", texture: 8, alpha: .82, pulse: .08, rim: .32, emissive: .08 }), E.part("sphere", add(p, [.22, .36, 0]), [.21, .23, .2], "#dce9f0", { alpha: .75, rim: .4 }));
    }
    out.push(E.part("arch", add(position, [0, .72, 0]), [1.3, 1.28, .38], "#3d3f46", { color2: "#191b20", texture: 3, roughness: .94 }));
    return out;
  }

  function siteParts(site, position, world, time) {
    const name = tag(site);
    if (!siteVisible(site, world)) return [];
    switch (name) {
      case "RedTownSite": return castleParts(position, "Castle", .38, number(state.$3.$2.$1), number(state.$3.$2.$2));
      case "BlueTownSite": return castleParts(position, "Necropolis", .38, number(state.$4.$2.$1), number(state.$4.$2.$2));
      case "GoldPileSite": return Array.from({ length: 8 }, (_, index) => E.part(index % 3 ? "disc" : "crystal", add(position, [(index % 4 - 1.5) * .18, .09 + Math.floor(index / 4) * .12, (index % 3 - 1) * .14]), [.14, .055 + index % 3 * .025, .14], "#e8b63d", { metallic: .64, roughness: .24, emissive: .05, rot: [0, index, 0] }));
      case "WoodPileSite": return Array.from({ length: 6 }, (_, index) => E.part("branch", add(position, [(index % 3 - 1) * .16, .12 + Math.floor(index / 3) * .18, 0]), [.09, .52, .09], index % 2 ? "#84582f" : "#654426", { rot: [Math.PI / 2, index * .14, Math.PI / 2], roughness: .96 }));
      case "ShrineSite": return shrineParts(position);
      case "ArtifactSite": return [E.part("crystal", add(position, [0, .55, 0]), [.35, .62, .35], "#f4ca53", { color2: "#7ed5ff", emissive: .34, rim: .48, pulse: .18, phase: time }), E.part("torus", add(position, [0, .15, 0]), [.56, .08, .56], "#d6c07b", { metallic: .7, roughness: .2 })];
      case "SawmillSite": return sawmillParts(position, tag(world.$4));
      case "GoldMineSite": return mineParts(position, tag(world.$5));
      case "GuardianSite": return guardianParts(position, time);
      default: return [];
    }
  }

  function mapDecoration(out, x, y, cell, position, time) {
    if (tag(cell.$1) !== "EmptySite") return;
    const terrain = tag(cell.$0);
    const seed = x * 31 + y * 47;
    if (terrain === "Grass" && seed % 7 === 0) out.push(...E.tree(seed % 2 ? "oak" : "pine", add(position, [-.28, .08, .16]), .22, time + seed, ["#604326", seed % 2 ? "#3f7337" : "#315b35"]));
    if ((terrain === "Rough" || terrain === "Rock") && seed % 3 === 0) out.push(E.part(seed % 2 ? "rock" : "shard", add(position, [.18, .25, -.16]), [.25, .32 + seed % 4 * .05, .24], "#68665d", { color2: "#3c3d39", texture: 3, roughness: 1, rot: [seed * .1, seed, 0] }));
    if (terrain === "Swamp" && seed % 4 === 0) out.push(E.part("branch", add(position, [.2, .2, .1]), [.08, .36, .08], "#4b3c27", { wind: .2, phase: time + seed, roughness: 1 }), E.part("sphere", add(position, [-.18, .08, -.14]), [.12, .08, .12], "#7c8650", { emissive: .06 }));
  }

  function heroParts(hero, owner, time, active) {
    const position = mapPoint(hero.$1, hero.$2, .12);
    const colors = ownerColors(owner);
    const parts = E.character(position, time * (active ? 3.1 : 1.4) + (owner === "Blue" ? 2 : 0), { scale: .28, skin: owner === "Blue" ? "#b9c2cb" : "#e8b989", cloth: colors.cloth, cloth2: colors.cloth2, accent: colors.accent, dark: colors.dark, hair: owner === "Blue" ? "#d6dae0" : "#5a3427", pack: "#6d5136" });
    parts.push(...flagParts(add(position, [-.25, .02, -.2]), owner, .36));
    return parts;
  }

  function buildAdventureScene(time) {
    const out = [];
    const world = state.$5;
    for (let y = 0; y < 7; y++) for (let x = 0; x < 9; x++) {
      const cell = cells[y][x], terrain = tag(cell.$0), style = terrainStyle[terrain], position = mapPoint(x, y, style.y);
      if (terrain === "Water") out.push(E.part("water", position, [.79, 1, .71], style.color, { color2: style.color2, alpha: .82, wave: .42, roughness: style.roughness, metallic: .12, caustic: .48 }));
      else out.push(E.part(terrain === "Rock" ? "island" : "bevel", [position[0], style.y - .16, position[2]], [.79, terrain === "Rock" ? .42 : .14, .71], style.color, { color2: style.color2, texture: style.texture, roughness: style.roughness }));
      mapDecoration(out, x, y, cell, position, time);
      out.push(...siteParts(cell.$1, add(position, [0, .08, 0]), world, time));
    }
    const redHero = state.$3.$1, blueHero = state.$4.$1;
    const active = tag(state.$2);
    shadow(out, mapPoint(redHero.$1, redHero.$2), .43, .3, .32);
    shadow(out, mapPoint(blueHero.$1, blueHero.$2), .43, .3, .32);
    out.push(...heroParts(redHero, "Red", time, active === "Red"), ...heroParts(blueHero, "Blue", time, active === "Blue"));
    for (let edge = -1; edge <= 1; edge += 2) for (let index = 0; index < 9; index++) out.push(E.part("rock", [edge * 8.15, -.15 + index % 2 * .12, (index - 4) * 1.28], [.55 + index % 3 * .13, .38 + index % 2 * .2, .48], "#41433d", { color2: "#262925", texture: 3, roughness: 1, rot: [index, index * .7, 0] }));
    const target = mapPoint(activeHero().$1, activeHero().$2, .3);
    const camera = orbit.camera(target);
    const night = active === "Blue";
    return {
      objects: out, camera, time, background: night ? "#253045" : "#7898a0",
      sun: { direction: night ? [.4, -1, -.2] : [-.45, -1, -.3], color: night ? "#aabde8" : "#fff0be" },
      point: { position: add(target, [0, 7, 1]), color: night ? "#a87fe2" : "#ffd98a" },
      fog: { color: night ? "#30394c" : "#87998d", density: .014 }, caustic: .4
    };
  }

  function dwellingParts(out, town, faction, time) {
    const mask = number(town.$3);
    const palette = faction === "Necropolis" ? ["#42344f", "#845dae"] : ["#8a744c", "#d7bd68"];
    const positions = [[-3.2, 0, -1.8], [-2.15, 0, 1.7], [-.9, 0, -2.3], [.9, 0, 2.2], [2.2, 0, -1.7], [3.25, 0, 1.4], [0, 0, -3.2]];
    const shapes = ["bevel", "arch", "rock", "torus", "shard", "cylinder", "crystal"];
    for (let tier = 0; tier < 7; tier++) if (mask & (1 << tier)) {
      const p = positions[tier], scale = .55 + tier * .075;
      out.push(E.part(shapes[tier], [p[0], .38 + tier * .04, p[2]], [scale, .48 + tier * .08, scale], tier % 2 ? palette[1] : palette[0], { color2: faction === "Necropolis" ? "#171827" : "#544127", texture: 3 + tier % 5, roughness: .72, emissive: tier === 6 ? .22 : 0, pulse: tier === 6 ? .08 : 0, phase: time + tier }));
      out.push(E.part("disc", [p[0], .035, p[2]], [scale * 1.2, .015, scale], "#070906", { alpha: .25 }));
    }
  }

  function buildTownScene(time) {
    const kingdom = activeKingdom(), town = kingdom.$2, faction = tag(town.$0), necro = faction === "Necropolis";
    const out = [E.part("island", [0, -.55, 0], [5.6, .54, 4.25], necro ? "#34333d" : "#617346", { color2: necro ? "#191923" : "#3b512f", texture: 3, roughness: .98 })];
    out.push(...castleParts([0, .02, 0], faction, 1.08, number(town.$1), number(town.$2)));
    dwellingParts(out, town, faction, time);
    if (necro) {
      for (let index = 0; index < 9; index++) out.push(E.part(index % 2 ? "shard" : "branch", [-4 + index, .25 + index % 3 * .12, 3 + Math.sin(index) * .45], [.11 + index % 2 * .07, .55 + index % 3 * .18, .11], index % 2 ? "#4a4857" : "#3c302b", { rot: [index * .2, index, index * .08], roughness: 1, emissive: index % 4 === 0 ? .05 : 0 }));
    } else {
      for (let index = 0; index < 6; index++) out.push(...E.tree(index % 2 ? "oak" : "cypress", [-4.1 + index * 1.62, 0, 3.15 + Math.sin(index) * .34], .42, time + index, ["#69492d", index % 2 ? "#46733d" : "#325c3b"]));
    }
    return { objects: out, camera: orbit.camera([0, 1.05, 0]), time, background: necro ? "#24283b" : "#88a8a3", sun: { direction: [-.4, -1, -.28], color: necro ? "#b6a4d8" : "#fff0c1" }, point: { position: [0, 7, 2], color: necro ? "#a977df" : "#ffd77a" }, fog: { color: necro ? "#33364a" : "#8d9e88", density: .012 } };
  }

  function turnParts(parts, pivot, reverse) {
    if (!reverse) return parts;
    return parts.map(part => {
      const dx = part.pos[0] - pivot[0], dz = part.pos[2] - pivot[2], rotation = part.rot || [0, 0, 0];
      return { ...part, pos: [pivot[0] - dx, part.pos[1], pivot[2] - dz], rot: [rotation[0], rotation[1] + Math.PI, rotation[2]] };
    });
  }

  function humanoid(position, side, phase, colors, scale = .44) {
    const parts = E.character(position, phase, { scale, skin: colors.skin || "#d7b08a", cloth: colors.cloth, cloth2: colors.cloth2, accent: colors.accent, dark: colors.dark, hair: colors.hair || "#4d3429", pack: colors.pack || colors.dark });
    return turnParts(parts, position, side === "enemy");
  }

  function horseParts(position, side, phase, palette) {
    const direction = side === "enemy" ? -1 : 1;
    const out = [
      E.part("capsule", add(position, [0, .65, 0]), [1.0, .48, .43], palette[0], { color2: palette[1], texture: 8, roughness: .62, rot: [0, 0, Math.PI / 2] }),
      E.part("capsule", add(position, [direction * .82, 1.02, 0]), [.36, .5, .34], palette[0], { rot: [0, 0, direction * -.45], roughness: .6 }),
      E.part("sphere", add(position, [direction * 1.02, 1.35, 0]), [.38, .34, .32], palette[0], { roughness: .55 }),
      E.part("branch", add(position, [-direction * 1.0, .75, 0]), [.07, .55, .07], palette[1], { rot: [0, 0, direction * 1.25], wind: .12, phase })
    ];
    for (const x of [-.55, .5]) for (const z of [-.26, .26]) out.push(E.part("capsule", add(position, [x, .2, z]), [.09, .38, .09], palette[1], { rot: [0, 0, Math.sin(phase + x * 3) * .18], roughness: .7 }));
    return out;
  }

  function creatureParts(kind, position, side, time, size = 1) {
    const phase = time * 2.2 + position[2];
    const friendly = side === "friendly";
    const direction = friendly ? 1 : -1;
    const p = [position[0], position[1], position[2]];
    let out = [];
    const red = { cloth: "#9f3930", cloth2: "#42201e", accent: "#e6cb7c", dark: "#292827", skin: "#d8ad82" };
    const blue = { cloth: "#354e7d", cloth2: "#18243f", accent: "#8eb4d8", dark: "#151927", skin: "#b9bdc1" };
    const living = friendly ? red : blue;
    if (kind === "Griffin") out.push(...turnParts(E.bird("stone", add(p, [0, .8, 0]), .08, phase, ["#b68c56", "#6f3d2c"]), add(p, [0, .8, 0]), !friendly));
    else if (kind === "Wight") out.push(...humanoid(add(p, [0, .08 + Math.sin(phase) * .08, 0]), side, phase, { cloth: "#748295", cloth2: "#303746", accent: "#b8d5d9", dark: "#202735", skin: "#dce7e6" }, .42).map(part => ({ ...part, alpha: .72, rim: .32, emissive: .05, pulse: .04 })));
    else if (kind === "Cavalier" || kind === "BlackKnight") {
      const dark = kind === "BlackKnight";
      out.push(...horseParts(p, side, phase, dark ? ["#242733", "#10121b"] : ["#8d7654", "#4e382a"]));
      out.push(...humanoid(add(p, [0, 1.0, 0]), side, phase, dark ? { cloth: "#232536", cloth2: "#0e1019", accent: "#8a6daf", dark: "#080a0d", skin: "#9ca5aa" } : living, .31));
      out.push(E.segment("branch", add(p, [direction * .25, 1.35, .35]), add(p, [direction * 1.65, 1.5, .35]), .035, dark ? "#915fd1" : "#d3d6d2", { metallic: .75, roughness: .18 }));
    } else if (kind === "BoneDragon") {
      out.push(E.part("birdBody", add(p, [0, .9, 0]), [1.25, .52, .42], "#c8c3aa", { color2: "#666a68", texture: 8, roughness: .83, rot: [0, friendly ? 0 : Math.PI, 0] }));
      for (let index = 0; index < 6; index++) out.push(E.part("torus", add(p, [-direction * .45 + direction * index * .18, .88, 0]), [.24, .06, .25], "#d3ceb7", { rot: [Math.PI / 2, 0, 0], roughness: .86 }));
      out.push(E.part("shard", add(p, [direction * 1.15, 1.04, 0]), [.48, .4, .38], "#d9d2b9", { rot: [0, 0, direction * -Math.PI / 2], roughness: .8 }));
      for (const sideZ of [-1, 1]) out.push(E.part(sideZ > 0 ? "wing" : "wingMirror", add(p, [-direction * .08, 1.1, sideZ * .22]), [1.08, .82, .95], "#6f7470", { rot: [sideZ * Math.sin(phase) * .25, friendly ? 0 : Math.PI, 0], doubleSided: true, alpha: .82, roughness: .9 }));
    } else {
      const palette = kind === "Skeleton" || kind === "Lich" ? { cloth: "#494459", cloth2: "#211e2d", accent: "#b8af91", dark: "#17151c", skin: "#d4d0bb" }
        : kind === "WalkingDead" ? { cloth: "#4d5a42", cloth2: "#283126", accent: "#6c7156", dark: "#24271e", skin: "#859071" }
        : kind === "Vampire" ? { cloth: "#54264f", cloth2: "#1d1224", accent: "#a33e4c", dark: "#111018", skin: "#c8bdc4" }
        : kind === "Monk" ? { cloth: "#d6d0b6", cloth2: "#6d2730", accent: "#e5c65e", dark: "#34252a", skin: "#d6ad86" }
        : living;
      out.push(...humanoid(p, side, phase, palette, kind === "Angel" ? .48 : .43));
      if (kind === "Pikeman") {
        out.push(E.segment("branch", add(p, [direction * .18, .74, .35]), add(p, [direction * 1.35, 1.55, .35]), .035, "#d3d2ca", { metallic: .74, roughness: .16 }), E.part("disc", add(p, [direction * .32, .82, -.34]), [.32, .06, .32], living.accent, { rot: [Math.PI / 2, 0, 0], metallic: .44 }));
      } else if (kind === "Archer") {
        out.push(E.part("torus", add(p, [direction * .42, .82, .32]), [.32, .045, .42], "#8a5e32", { rot: [Math.PI / 2, 0, 0], roughness: .74 }), E.segment("branch", add(p, [direction * .1, 1.05, .34]), add(p, [direction * 1.2, 1.05, .34]), .02, "#d7d0ae", { metallic: .32 }));
      } else if (kind === "Swordsman") {
        out.push(E.segment("shard", add(p, [direction * .2, .82, .38]), add(p, [direction * .95, 1.35, .38]), .06, "#d6dde0", { metallic: .84, roughness: .12 }), E.part("disc", add(p, [direction * .28, .82, -.36]), [.36, .07, .36], "#b8b6ad", { color2: living.flag, texture: 7, rot: [Math.PI / 2, 0, 0], metallic: .55 }));
      } else if (kind === "Monk" || kind === "Lich") {
        out.push(E.segment("branch", add(p, [direction * .12, .48, .38]), add(p, [direction * .35, 1.72, .38]), .035, kind === "Lich" ? "#6e5382" : "#87613c", { roughness: .5 }), E.part("star", add(p, [direction * .37, 1.8, .38]), [.16, .05, .16], kind === "Lich" ? "#ad76e2" : "#f2d56e", { emissive: .38, pulse: .14, rot: [Math.PI / 2, 0, 0] }));
      } else if (kind === "Vampire") {
        for (const sideZ of [-1, 1]) out.push(E.part(sideZ > 0 ? "wing" : "wingMirror", add(p, [-direction * .25, 1.05, sideZ * .16]), [.55, .48, .58], "#4d1834", { rot: [sideZ * .25, friendly ? 0 : Math.PI, direction * .3], doubleSided: true, roughness: .78 }));
      } else if (kind === "Angel") {
        for (const sideZ of [-1, 1]) out.push(E.part(sideZ > 0 ? "wing" : "wingMirror", add(p, [-direction * .28, 1.25, sideZ * .22]), [.84, .75, .82], "#f1eee0", { rot: [sideZ * Math.sin(phase) * .18, friendly ? 0 : Math.PI, direction * .25], doubleSided: true, roughness: .48, rim: .18, subsurface: .12 }));
        out.push(E.segment("shard", add(p, [direction * .22, .9, .38]), add(p, [direction * 1.18, 1.48, .38]), .055, "#f5df79", { metallic: .75, emissive: .12 }));
      }
    }
    shadow(out, p, .65 * size, .38 * size, .28);
    return out.map(part => size === 1 ? part : { ...part, scale: part.scale.map(value => value * size) });
  }

  function battleFxParts(out, time, friendlyPositions, enemyPositions) {
    if (!actionFx) return;
    const elapsed = time - actionFx.start;
    if (elapsed > 1.15) { actionFx = null; return; }
    const source = friendlyPositions[actionFx.own] || friendlyPositions.find(Boolean) || [-4, .8, 0];
    const target = enemyPositions[actionFx.target] || enemyPositions.find(Boolean) || [4, .8, 0];
    const progress = clamp(elapsed / .72, 0, 1);
    if (actionFx.command === 22) {
      for (let index = 0; index < 14; index++) {
        const t = clamp(progress * 1.4 - index * .035, 0, 1);
        const p = source.map((value, axis) => value + (target[axis] - value) * t);
        out.push(E.part(index % 3 ? "sphere" : "crystal", add(p, [0, .7 + Math.sin(t * Math.PI) * 1.7, 0]), [.08 + index % 3 * .025, .08 + index % 3 * .025, .08 + index % 3 * .025], index % 2 ? "#78cfff" : "#eee8ff", { alpha: .82, emissive: .55, rim: .5, pulse: .2, phase: index }));
      }
    } else if (actionFx.command === 21) {
      for (let ring = 0; ring < 4; ring++) out.push(E.part("torus", add(source, [0, .75, 0]), [.58 + ring * .13 + progress * .24, .04, .58 + ring * .13 + progress * .24], "#8ad7ff", { alpha: .55 - ring * .09, emissive: .25, rot: [Math.PI / 2, 0, 0] }));
    } else if (actionFx.command === 20) {
      for (let spark = 0; spark < 18; spark++) { const angle = spark / 18 * Math.PI * 2; out.push(E.part(spark % 4 ? "star" : "shard", add(target, [Math.sin(angle) * progress * .8, .65 + Math.cos(angle * 2) * progress * .65, Math.cos(angle) * progress * .8]), [.06, .025, .06], spark % 2 ? "#ffd36b" : "#eef5ff", { alpha: 1 - progress * .65, emissive: .45, rot: [angle, angle * 2, 0] })); }
    }
  }

  function buildCombatScene(time) {
    const out = [];
    const battle = state.$6.$0;
    const friendly = activeHero().$11, enemy = battle.$2;
    for (let row = 0; row < 11; row++) for (let column = 0; column < 15; column++) {
      const x = (column - 7) * .72 + (row % 2) * .36, z = (row - 5) * .61;
      out.push(E.part("disc", [x, -.04, z], [.38, .035, .34], (row + column) % 2 ? "#6d704e" : "#777456", { color2: "#404531", texture: 3, roughness: .98 }));
    }
    for (let index = 0; index < 10; index++) out.push(E.part(index % 3 ? "rock" : "shard", [-6.2 + index * 1.38, .05 + index % 2 * .1, -3.85 + Math.sin(index) * .28], [.28 + index % 3 * .08, .22 + index % 2 * .18, .3], "#55564d", { texture: 3, roughness: 1, rot: [index, index * .8, 0] }));
    const friendlyPositions = Array(7).fill(null), enemyPositions = Array(7).fill(null);
    armySlots(friendly).forEach((stack, index) => {
      if (tag(stack) !== "Troop") return;
      const p = [-4.45 + (index % 2) * .32, .05, (index - 3) * .85]; friendlyPositions[index] = p;
      out.push(...creatureParts(tag(stack.$0), p, "friendly", time, .72 + Math.min(.2, Math.log10(number(stack.$1) + 1) * .08)));
    });
    armySlots(enemy).forEach((stack, index) => {
      if (tag(stack) !== "Troop") return;
      const p = [4.45 - (index % 2) * .32, .05, (index - 3) * .85]; enemyPositions[index] = p;
      out.push(...creatureParts(tag(stack.$0), p, "enemy", time, .72 + Math.min(.2, Math.log10(number(stack.$1) + 1) * .08)));
    });
    battleFxParts(out, time, friendlyPositions, enemyPositions);
    return { objects: out, camera: orbit.camera([0, .8, 0]), time, background: "#303b38", sun: { direction: [-.35, -1, -.24], color: "#f5dfb0" }, point: { position: [0, 6, 2], color: "#94c5dd" }, fog: { color: "#454c46", density: .018 } };
  }

  function project(point, camera) {
    const forward = norm(sub(camera.target, camera.eye)), right = norm(cross(forward, camera.up || [0, 1, 0])), up = cross(right, forward), relative = sub(point, camera.eye);
    const depth = dot(relative, forward);
    if (depth <= .01) return null;
    const tangent = Math.tan((camera.fov || 48) * Math.PI / 360), aspect = Math.max(1, canvas.clientWidth) / Math.max(1, canvas.clientHeight);
    const nx = dot(relative, right) / (depth * tangent * aspect), ny = dot(relative, up) / (depth * tangent);
    return { x: (nx + 1) * .5 * canvas.clientWidth, y: (1 - ny) * .5 * canvas.clientHeight, visible: Math.abs(nx) <= 1.1 && Math.abs(ny) <= 1.1 };
  }

  function placeHotspots(camera) {
    for (const entry of hotspotEntries) {
      const point = project(mapPoint(entry.x, entry.y, .25), camera);
      entry.button.hidden = !point?.visible;
      if (point) { entry.button.style.left = `${point.x}px`; entry.button.style.top = `${point.y}px`; }
    }
  }

  function rebuildHotspots() {
    const root = $("map-hotspots"); root.replaceChildren(); hotspotEntries = [];
    if (tag(state.$6) !== "Adventure" || sceneMode !== "map") return;
    const hero = activeHero(), x = number(hero.$1), y = number(hero.$2);
    for (const [command, dx, dy, label, diagonal] of [
      [0, 0, -1, "Move north", false], [9, 1, -1, "Move north-east", true],
      [1, 1, 0, "Move east", false], [10, 1, 1, "Move south-east", true],
      [2, 0, 1, "Move south", false], [11, -1, 1, "Move south-west", true],
      [3, -1, 0, "Move west", false], [12, -1, -1, "Move north-west", true]
    ]) {
      const nx = x + dx, ny = y + dy;
      if (nx < 0 || nx >= 9 || ny < 0 || ny >= 7 || !cells[ny][nx].$3) continue;
      const baseCost = number(cells[ny][nx].$2), moveCost = diagonal ? Math.round(baseCost * 1.41) : baseCost;
      const button = document.createElement("button"); button.className = "map-hotspot"; button.title = `${label}: ${tag(cells[ny][nx].$0)} · ${moveCost} movement`;
      button.setAttribute("aria-label", button.title); button.onclick = () => run(command); root.append(button); hotspotEntries.push({ button, x: nx, y: ny });
    }
  }

  function setSceneMode(mode) {
    if (tag(state.$6) === "Combat") mode = "combat";
    sceneMode = mode;
    if (mode === "map") Object.assign(orbit.state, { yaw: -.63, pitch: .77, distance: 16.2 });
    if (mode === "town") Object.assign(orbit.state, { yaw: .66, pitch: .27, distance: 12.5 });
    if (mode === "combat") Object.assign(orbit.state, { yaw: .02, pitch: .3, distance: 10.8 });
    $("view-map").setAttribute("aria-pressed", String(mode === "map"));
    $("view-town").setAttribute("aria-pressed", String(mode === "town"));
    rebuildHotspots();
  }

  function renderResources(resources) {
    $("resources-top").innerHTML = resourceNames.map((name, index) => `<div class="resource"><span>${name}</span><b>${number(resources[`$${index}`]).toLocaleString()}</b></div>`).join("");
  }

  function renderHero(hero) {
    const movement = number(hero.$3), mana = number(hero.$8), maxMana = Math.max(1, number(hero.$7) * 10), army = armySlots(hero.$11);
    $("hero-position").textContent = `${number(hero.$1)},${number(hero.$2)}`;
    $("hero").innerHTML = `
      <div class="hero-row"><div class="portrait">${String(hero.$0).slice(0, 1)}</div><div><h3>${hero.$0}</h3><p>Level ${number(hero.$9)} · ${number(hero.$10).toLocaleString()} experience</p></div></div>
      <div class="stats"><div><span>Attack</span><b>${number(hero.$4)}</b></div><div><span>Defense</span><b>${number(hero.$5)}</b></div><div><span>Power</span><b>${number(hero.$6)}</b></div><div><span>Knowledge</span><b>${number(hero.$7)}</b></div></div>
      <div class="meters"><div class="meter"><span>Movement</span><div class="bar"><i style="width:${clamp(movement / 16, 0, 100)}%"></i></div><b>${movement}</b></div><div class="meter"><span>Mana</span><div class="bar mana"><i style="width:${clamp(mana / maxMana * 100, 0, 100)}%"></i></div><b>${mana}/${maxMana}</b></div></div>
      <div class="army">${army.map((stack, index) => `<div class="army-slot" title="Slot ${index + 1}: ${stackText(stack)}"><b>${tag(stack) === "Troop" ? (creatureNames[tag(stack.$0)] || tag(stack.$0)) : "—"}</b><span>${tag(stack) === "Troop" ? number(stack.$1) : ""}</span></div>`).join("")}</div>`;
  }

  function renderTown(town) {
    const faction = tag(town.$0), stock = town.$5, mask = number(town.$3), hero = activeHero();
    const atHome = faction === "Castle" ? number(hero.$1) === 1 && number(hero.$2) === 5 : number(hero.$1) === 7 && number(hero.$2) === 1;
    $("town-faction").textContent = faction;
    $("town").innerHTML = `
      <div class="town-summary"><div><b>${number(town.$1)}</b><span>Hall</span></div><div><b>${number(town.$2)}</b><span>Fort</span></div><div><b>${town.$4 ? "Used" : "Ready"}</b><span>Build</span></div></div>
      <div class="town-actions"><button data-town-command="5">Advance hall</button><button data-town-command="6">Advance fort</button></div>
      <div class="recruit-row"><select id="tier">${tierNames[faction].map((name, index) => `<option value="${index + 1}">${index + 1} · ${name} · ${number(stock[`$${index}`])} ready${mask & (1 << index) ? "" : " · locked"}</option>`).join("")}</select><input id="amount" type="number" min="1" max="999" value="1" aria-label="Recruit amount"><button id="build-dwelling">Build selected dwelling</button><button id="recruit">Recruit selected creatures</button></div>
      <p style="margin:8px 0 0;color:var(--muted);font-size:11px">${atHome ? "The active hero is visiting this town." : "Return the active hero home to recruit into the field army."}</p>`;
    $("town").querySelectorAll("[data-town-command]").forEach(button => button.onclick = () => run(number(button.dataset.townCommand)));
    $("build-dwelling").onclick = () => run(7, number($("tier").value), 0);
    $("recruit").disabled = !atHome;
    $("recruit").onclick = () => run(8, number($("tier").value), Math.max(1, number($("amount").value)));
  }

  function occupiedOptions(army) {
    return armySlots(army).map((stack, index) => ({ stack, index })).filter(entry => tag(entry.stack) === "Troop").map(entry => `<option value="${entry.index}">${entry.index + 1} · ${stackText(entry.stack)}</option>`).join("");
  }

  function rosterMarkup(army) {
    return armySlots(army).map((stack, index) => `<div class="roster-card"><b>${index + 1} · ${tag(stack) === "Troop" ? creatureNames[tag(stack.$0)] || tag(stack.$0) : "Empty"}</b>${tag(stack) === "Troop" ? number(stack.$1) : "—"}</div>`).join("");
  }

  function renderCombat(phase) {
    const battle = phase.$0, friendly = activeHero().$11, enemy = battle.$2;
    $("own-slot").innerHTML = occupiedOptions(friendly); $("target-slot").innerHTML = occupiedOptions(enemy);
    $("friendly-roster").innerHTML = rosterMarkup(friendly); $("enemy-roster").innerHTML = rosterMarkup(enemy);
    $("scene-name").textContent = `${tag(battle.$1) === "GuardianBattle" ? "Bridge guardians" : "Town siege"} · round ${number(battle.$3)}`;
    $("scene-subtitle").textContent = "All damage, casualties, mana and outcomes return from Bend2 Core";
  }

  function renderUI() {
    const date = calendar(state.$1), active = tag(state.$2), phase = state.$6, phaseName = tag(phase), kingdom = activeKingdom(), hero = kingdom.$1;
    $("date").textContent = `Month ${date.month} · Week ${date.week} · Day ${date.day}`;
    $("active").textContent = `${active} turn`; $("phase").textContent = phaseName; $("seed-state").textContent = number(state.$7).toLocaleString();
    $("notice").textContent = state.$9; renderResources(kingdom.$0); renderHero(hero); renderTown(kingdom.$2);
    $("undo").disabled = history.length === 0;
    $("adventure-controls").hidden = phaseName !== "Adventure"; $("combat-controls").hidden = phaseName !== "Combat";
    $("view-map").disabled = phaseName === "Combat"; $("view-town").disabled = phaseName === "Combat";
    $("victory").hidden = phaseName !== "Victory";
    if (phaseName === "Victory") { $("victory-title").textContent = `${tag(phase.$0)} is victorious`; sceneMode = "map"; }
    if (phaseName === "Combat") { setSceneMode("combat"); renderCombat(phase); }
    else {
      $("scene-name").textContent = sceneMode === "town" ? `${tag(kingdom.$2.$0)} town` : "Erathian frontier";
      $("scene-subtitle").textContent = sceneMode === "town" ? "Core buildings and dwelling mask projected through Bend Engine" : `${hero.$0} · ${number(hero.$3)} movement points`;
      rebuildHotspots();
    }
  }

  function run(command, arg0 = 0, arg1 = 0) {
    const oldPhase = tag(state.$6); history.push(state);
    state = Core.step(state, command, arg0, arg1);
    actionFx = { command, own: arg0, target: arg1, start: performance.now() / 1000 };
    if (oldPhase !== "Combat" && tag(state.$6) === "Combat") setSceneMode("combat");
    if (oldPhase === "Combat" && tag(state.$6) !== "Combat") setSceneMode("map");
    renderUI();
  }

  function draw(milliseconds) {
    const time = milliseconds / 1000;
    let scene;
    if (tag(state.$6) === "Combat") scene = buildCombatScene(time);
    else if (sceneMode === "town") scene = buildTownScene(time);
    else scene = buildAdventureScene(time);
    const stats = renderer.render(scene); $("triangles").textContent = Math.round(stats.triangles).toLocaleString();
    if (sceneMode === "map" && tag(state.$6) === "Adventure") placeHotspots(scene.camera);
    previousFrame = milliseconds;
    requestAnimationFrame(draw);
  }

  $("north").onclick = () => run(0); $("east").onclick = () => run(1); $("south").onclick = () => run(2); $("west").onclick = () => run(3);
  $("northeast").onclick = () => run(9); $("southeast").onclick = () => run(10); $("southwest").onclick = () => run(11); $("northwest").onclick = () => run(12);
  $("end-turn").onclick = () => run(4);
  $("view-map").onclick = () => { setSceneMode("map"); renderUI(); };
  $("view-town").onclick = () => { setSceneMode("town"); renderUI(); };
  $("undo").onclick = () => { if (history.length) state = history.pop(); setSceneMode(tag(state.$6) === "Combat" ? "combat" : "map"); renderUI(); };
  $("new-game").onclick = () => { state = Core.newGame(Math.max(0, number($("seed").value)) >>> 0); history = []; actionFx = null; setSceneMode("map"); renderUI(); };
  $("save").onclick = () => { localStorage.setItem("bend-heroes-state", JSON.stringify(state)); $("notice").textContent = "The immutable Core state was saved in this browser."; };
  $("load").onclick = () => { const saved = localStorage.getItem("bend-heroes-state"); if (!saved) return void ($("notice").textContent = "No local save exists."); history.push(state); state = JSON.parse(saved); setSceneMode(tag(state.$6) === "Combat" ? "combat" : "map"); renderUI(); };
  $("combat-controls").querySelectorAll("[data-combat]").forEach(button => button.onclick = () => run(number(button.dataset.combat), number($("own-slot").value), number($("target-slot").value)));
  addEventListener("keydown", event => {
    if (/INPUT|SELECT|TEXTAREA/.test(document.activeElement?.tagName || "") || tag(state.$6) !== "Adventure") return;
    const commands = { ArrowUp: 0, ArrowRight: 1, ArrowDown: 2, ArrowLeft: 3, PageUp: 9, PageDown: 10, End: 11, Home: 12, "9": 9, "3": 10, "1": 11, "7": 12 };
    if (commands[event.key] !== undefined) { event.preventDefault(); run(commands[event.key]); }
  });
  orbit.onChange(() => { if (sceneMode === "map") rebuildHotspots(); });

  globalThis.BEND_HEROES_VIEWER = {
    run, render: renderUI, setSceneMode,
    get state() { return state; },
    set state(value) { history.push(state); state = value; renderUI(); },
    get sceneMode() { return sceneMode; }
  };
  setSceneMode("map"); renderUI(); requestAnimationFrame(draw);
})();
