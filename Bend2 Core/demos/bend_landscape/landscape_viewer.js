(() => {
  "use strict";
  const E = globalThis.BEND_ENGINE_WEBGL, Core = globalThis.BEND_LANDSCAPE_DATA_CORE, $ = id => document.getElementById(id);
  const list = value => { const out = []; while (value?.$ === "Con") { out.push(value.$0); value = value.$1; } return out; };
  const tag = value => value?.$ || "";
  const sandCount = value => Number(value.$0);
  const tideHeight = { TideLow: 170, TideRisingOne: 182, TideRisingTwo: 194, TideCrest: 206, TideFallingOne: 194, TideFallingTwo: 182, TideRest: 170 };
  const terrainHeight = { TerrainShore: 220, TerrainDune: 238, TerrainMeadow: 256, TerrainRise: 274, TerrainHill: 292, TerrainDescent: 256 };
  const whaleColors = { WhaleGrey: "#6f8794", WhaleSlateBlue: "#536f8b", WhaleOceanBlue: "#2d6288", WhaleWhiteMorph: "#e7eef1", WhaleBlackMorph: "#151d28" };
  const fishPalette = { Sardine: ["#9fd5da", "#426d80"], Anchovy: ["#b6cdd1", "#435766"], Mackerel: ["#4e9db2", "#183f55"], Tuna: ["#387fa0", "#b2d5d4"], FlyingFish: ["#56c9db", "#7357b6"], LanternFish: ["#1a3c63", "#7ff4df"], ReefBass: ["#e08f55", "#57335e"], MoonJelly: ["#cfb8ff", "#5edee8"], Manta: ["#3c526c", "#b7cad7"], Shark: ["#6f8796", "#d5e1e5"], Seahorse: ["#efb24c", "#8d5233"], RibbonEel: ["#244ec2", "#f5df4a"] };
  const fishKinds = Object.fromEntries(Object.keys(fishPalette).map((name, index) => [name, index]));
  const birdColors = { Gull: "#ecf3f3", Tern: "#d8e1e5", Heron: "#8197a0", Swift: "#3e4355", Kingfisher: "#2eb3bd", Cormorant: "#202834", SongThrush: "#a8784f", Kite: "#874d37" };
  const skinColors = { SkinPorcelain: "#f4d1b7", SkinLight: "#e5b18b", SkinOlive: "#b98258", SkinBrown: "#885139", SkinDeep: "#4e2b25" };
  const treeColors = { CoastOak: ["#6b472e", "#3e8b48"], StonePine: ["#70482e", "#236046"], WeepingWillow: ["#7c5730", "#70ae4e"], FruitTree: ["#6e472b", "#4ca94e"], Baobab: ["#8a6648", "#6f9a47"], Mangrove: ["#74503a", "#358059"], SilverBirch: ["#d8d2c4", "#78ad55"], Cypress: ["#795238", "#27583c"] };
  const canvas = $("landscape"), renderer = E.create(canvas), orbit = E.bindOrbit(canvas, { yaw: .28, pitch: .15, distance: 28, target: [10, 1.5, 0] });
  let key = 731, boundary, nextIndex, chunks, cameraX, playing = true, speed = 1, pov = "side", last = 0, audio = null, lastCallChunk = -1;

  function parseChunk(raw) {
    const sea = raw.$4, land = raw.$5, sky = raw.$6, weather = raw.$7;
    return {
      raw, key: Number(raw.$0), index: Number(raw.$1), origin: Number(raw.$2), boundary: raw.$3,
      sea: { waterY: Number(sea.$0), sand: tag(sea.$1), whales: list(sea.$2), rocks: list(sea.$3), fish: list(sea.$4), schools: list(sea.$5) },
      land: { terrain: tag(land.$0), trees: list(land.$1), hills: list(land.$2), humans: land.$3 },
      sky: { birds: list(sky.$0), clouds: list(sky.$1) },
      weather: { wind: tag(weather.$0), tide: tag(weather.$1), cloud: tag(weather.$2), rain: tag(weather.$3), sun: tag(weather.$4), windForce: Number(weather.$5), tideY: Number(weather.$6), rainAmount: Number(weather.$7), light: Number(weather.$8) },
      placement: raw.$8
    };
  }

  function generateOne() {
    const step = Core.next(key, nextIndex, boundary); chunks.push(parseChunk(step.$0)); boundary = step.$1; nextIndex++;
  }
  function reset(value) {
    key = Math.max(0, Math.min(4294967295, Number(value) || 0)); boundary = Core.initial(key); nextIndex = 0; chunks = []; cameraX = 0;
    for (let i = 0; i < 12; i++) generateOne();
    $("key").value = key; lastCallChunk = -1;
  }

  const wx = (chunk, slot) => chunk.origin / 50 + Number(slot) / 50;
  const terrainY = chunk => .1 + terrainHeight[chunk.land.terrain] / 100;
  const waterY = chunk => -2.9 + chunk.sea.waterY / 100;
  const phase = (value, offset = 0) => (Number(value) + Number(offset)) / 360 * Math.PI * 2;
  const shadow = (x, y, z, sx, sz, alpha = .18) => E.part("disc", [x, y, z], [sx, .012, sz], "#06100d", { alpha, roughness: 1 });

  function addSand(objects, chunk, nextChunk) {
    const count = sandCount(chunk.raw.$4.$1), x0 = chunk.origin / 50 + 9, nextWater = nextChunk ? waterY(nextChunk) : waterY(chunk);
    for (let layer = 0; layer < count; layer++) objects.push(E.part("island", [x0, -2.5 - layer * .21, .25], [9.35, .42, 5.95], layer % 2 ? "#d1ad68" : "#edd18a", { color2: "#8c7043", texture: 3, roughness: .94 }));
    for (let s = 0; s < 8; s++) { const t = (s + .5) / 8, x = chunk.origin / 50 + t * 18, y = waterY(chunk) + (nextWater - waterY(chunk)) * t; objects.push(E.part("water", [x, y, -2.4], [1.16, 1, 3.5], "#187fab", { color2: "#5ed4e5", alpha: .7, wave: .28 + chunk.weather.windForce / 220, roughness: .045, metallic: .12, caustic: chunk.weather.light / 255 }), E.part("torus", [x, y + .025, .45], [1.08, .018, .34], "#d8fbef", { alpha: .15 + chunk.weather.windForce / 1800, roughness: .08, rot: [0, s * .25, 0] })); }
    for (let detail = 0; detail < 7; detail++) { const x = chunk.origin / 50 + 1.3 + detail * 2.35, z = .5 + (detail % 3) * .42; objects.push(E.part(detail % 3 ? "rock" : "torus", [x, -1.95 + detail % 2 * .08, z], detail % 3 ? [.16 + detail % 2 * .06, .11, .2] : [.12, .045, .12], detail % 3 ? "#8f846a" : "#eac59e", { roughness: .92, rot: [detail * .2, detail * .8, 0] })); }
  }

  function addWhales(objects, chunk) {
    for (const whale of chunk.sea.whales) {
      const sizeTag = tag(whale.$2), scale = sizeTag === "WhaleJuvenile" ? .72 : sizeTag === "WhaleGreat" ? 1.35 : 1, pct = Number(whale.$3.$0) / 100, x = wx(chunk, whale.$5), y = waterY(chunk) - .48 + pct * 2.1, z = -2.7, color = whaleColors[tag(whale.$1)], ph = phase(whale.$6, chunk.index * 11);
      objects.push(...E.whale([x, y, z], scale, ph * .06, ph, color), shadow(x, waterY(chunk) + .012, z, 1.8 * scale, .75 * scale, .12));
      if (whale.$4.$0 === true || tag(whale.$4.$0) === "True") { const volume = Number(whale.$4.$1), amount = volume >= 110 ? 18 : volume >= 75 ? 12 : 7; for (let i = 0; i < amount; i++) objects.push(E.part("sphere", [x + Math.sin(i * 2.3) * i * .018, y + .72 + i * .11, z + Math.cos(i * 1.8) * i * .014], [.04 + i % 3 * .012, .04 + i % 3 * .012, .04 + i % 3 * .012], "#d8fbff", { alpha: .66 })); }
    }
  }

  function addSeaRocks(objects, chunk) {
    for (const rock of chunk.sea.rocks) { const x = wx(chunk, rock.$3), size = Number(rock.$4) / 85, protrude = { RockSubmerged: -.6, RockLow: -.15, RockMedium: .18, RockHigh: .45 }[tag(rock.$2)], y = waterY(chunk) - .7 + protrude, shape = tag(rock.$1); if (shape === "SeaRockCluster") for (let i = 0; i < 5; i++) objects.push(E.part(i % 3 ? "rock" : "shard", [x + (i - 2) * .22, y + i % 2 * .16, -1.7 + (i % 3) * .3], [.28 * size, (.42 + i % 2 * .26) * size, .28 * size], i % 2 ? "#59676b" : "#39494f", { roughness: .92, texture: 3, rot: [i * .17, i * .7, (i - 2) * .08] })); else objects.push(E.part(shape === "SeaRockSharp" ? "shard" : "rock", [x, y, -1.7], [.55 * size, .85 * size, .5 * size], "#506064", { color2: "#283a3f", texture: 3, roughness: .94, rot: [0, Number(rock.$0) * .7, 0] })); }
  }

  function addFish(objects, chunk) {
    for (const fish of chunk.sea.fish) { const species = tag(fish.$1), p = [wx(chunk, fish.$3), waterY(chunk) - Number(fish.$4) / 110, -2.2 + Math.sin(phase(fish.$6, fish.$0)) * .8], palette = fishPalette[species], size = Number(fish.$5) / 75, heading = phase(fish.$6); objects.push(...E.fish(fishKinds[species], p, size, heading, phase(fish.$6, chunk.index * 13), palette)); }
    for (const school of chunk.sea.schools) { const species = tag(school.$1), members = list(school.$3), centerX = wx(chunk, school.$4), centerY = waterY(chunk) - Number(school.$5) / 120, heading = phase(school.$6), palette = fishPalette[species]; for (const member of members) { const p = [centerX + Number(member.$1) / 160 - .6, centerY + Number(member.$2) * .11 - .22, -3 + Number(member.$3) * .075 - .3]; objects.push(...E.fish(fishKinds[species], p, .34, heading, phase(school.$6, member.$4), palette)); } }
  }

  function addHills(objects, chunk, nextChunk) {
    const x0 = chunk.origin / 50, y0 = terrainY(chunk), y1 = nextChunk ? terrainY(nextChunk) : y0;
    for (let s = 0; s < 8; s++) { const t = (s + .5) / 8, y = y0 + (y1 - y0) * t; objects.push(E.part("island", [x0 + t * 18, y - .62, 1.6], [1.22, .58, 4.4], chunk.land.terrain === "TerrainDune" ? "#c9a85e" : "#538a49", { color2: chunk.land.terrain === "TerrainHill" ? "#304f39" : "#856f3e", texture: 3, roughness: .96 })); }
    for (const hill of chunk.land.hills) { const x = wx(chunk, hill.$2), h = Number(hill.$3) / 90, w = Number(hill.$4) / 120, shape = tag(hill.$1); objects.push(E.part(shape === "RockyRise" ? "rock" : "island", [x, y0 + h * .18, 1.9], [w, h, 2.1], shape === "DuneHill" ? "#c9ad6b" : shape === "RockyRise" ? "#6c746c" : "#4f7848", { color2: "#344d35", texture: 3, roughness: .94, rot: [0, Number(hill.$0) * .27, 0] })); }
  }

  function addTrees(objects, chunk) {
    const baseY = terrainY(chunk);
    for (const tree of chunk.land.trees) { const x = wx(chunk, tree.$2), h = Number(tree.$3) / 100, crown = Number(tree.$4) / 130, colors = treeColors[tag(tree.$1)], wind = chunk.weather.windForce / 255 * Number(tree.$6) / 110, z = 1.2 + Number(tree.$0) % 3 * 1.05, treeSize = Math.max(.42, (h + crown) * .42); objects.push(...E.tree(tag(tree.$1), [x, baseY, z], treeSize, phase(tree.$7, chunk.index * 13) + wind, colors)); const top = [x + wind * h * .14, baseY + treeSize * 2.05, z], fruit = tree.$9; if (tag(fruit) !== "FruitAbsent") { const count = Math.min(9, Number(fruit.$0)); for (let i = 0; i < count; i++) { const falling = tag(fruit) === "FruitFalling", fy = falling ? baseY + (Number(fruit.$1) + i * 13) % 100 / 100 * h : top[1] - .2 - i % 3 * .16; objects.push(E.part("star", [top[0] + Math.sin(i * 2.4) * crown * .62, fy, z + Math.cos(i * 1.7) * crown * .55], [.085, .05, .085], i % 2 ? "#f0c640" : "#d94d36", { roughness: .5, rot: [Math.PI / 2, i, 0] })); } } }
  }

  function humans(value) { return list(value.$0); }
  function addHumans(objects, chunk) { const baseY = terrainY(chunk); for (const person of humans(chunk.land.humans)) { const x = wx(chunk, person.$6), z = 2.2 + Number(person.$0) * .35, skin = skinColors[tag(person.$1)], action = tag(person.$5), ph = phase(person.$7, chunk.index * 9), tall = tag(person.$2) === "BodyTall" ? 1.16 : tag(person.$2) === "BodySmall" ? .84 : 1, cloth = tag(person.$3) === "ClothesRaincoat" ? "#f2c62c" : tag(person.$3) === "ClothesWorker" ? "#566c93" : "#8e4d72"; objects.push(...E.character([x, baseY, z], ph, { scale: tall * .55, skin, cloth, cloth2: "#29334c", accent: cloth, dark: "#303547", pack: "#6f5036" })); if (action === "HumanDigRock" || action === "HumanCutTree") { const hand = [x + .22, baseY + .75, z + .36], tip = [x + .62, baseY + 1.05 + Math.sin(ph) * .14, z + .36]; objects.push(E.segment("branch", hand, tip, .025, "#765234", { roughness: .82 }), E.part(action === "HumanDigRock" ? "shard" : "fin", tip, [.12, .16, .08], "#aab4b7", { metallic: .72, roughness: .2, rot: [0, 0, ph] })); } }
  }

  function addBirds(objects, chunk) { const baseY = terrainY(chunk); for (const bird of chunk.sky.birds) { const action = tag(bird.$3), flying = action === "BirdFlying", x = wx(chunk, bird.$4), y = flying ? 4.5 + Number(bird.$5) / 170 : baseY + 2.3, z = flying ? -1 + Number(bird.$0) % 4 * 1.1 : 1.2 + Number(bird.$0) % 3, size = Number(bird.$6) / 75, ph = phase(bird.$8, chunk.index * 17), color = birdColors[tag(bird.$1)]; objects.push(...E.wildBird([x, y, z], size, flying ? 0 : Math.PI * .08, ph, [color, "#283746"], flying)); } }

  function addClouds(objects, chunk) { for (const cloud of chunk.sky.clouds) { const x = wx(chunk, cloud.$4) + chunk.weather.windForce / 50, y = 7 + Number(cloud.$5) / 190, z = -1 + Number(cloud.$0) % 3 * 2.3, scale = tag(cloud.$2) === "CloudMerged" ? 1.75 : tag(cloud.$2) === "CloudLarge" ? 1.35 : tag(cloud.$2) === "CloudSmall" ? .7 : 1, opacity = Number(cloud.$6) / 255; objects.push(...E.cloud([x, y, z], scale, chunk.weather.rain === "RainHeavy" ? "#667786" : "#e7f0f1", chunk.index + Number(cloud.$0), Math.min(.92, .45 + opacity * .45))); if (chunk.weather.rainAmount > 0) for (let i = 0; i < Math.min(26, chunk.weather.rainAmount / 3); i++) { const start = [x + (i % 9 - 4) * .42, y - .65 - Math.floor(i / 9) * .7, z + Math.sin(i) * .5], end = [start[0] + chunk.weather.windForce / 255 * .22, start[1] - .68, start[2]]; objects.push(E.segment("capsule", start, end, .012, "#8ad7ed", { alpha: .42 })); } } }

  function playCall(call) { if (!audio || call === "CallSilent") return; const frequencies = { CallChirp: 1380, CallTrill: 980, CallCry: 620, CallWhistle: 1740 }, oscillator = audio.createOscillator(), gain = audio.createGain(), now = audio.currentTime; oscillator.type = call === "CallCry" ? "sawtooth" : "sine"; oscillator.frequency.setValueAtTime(frequencies[call] || 900, now); oscillator.frequency.exponentialRampToValueAtTime((frequencies[call] || 900) * 1.18, now + .12); gain.gain.setValueAtTime(.0001, now); gain.gain.exponentialRampToValueAtTime(.035, now + .02); gain.gain.exponentialRampToValueAtTime(.0001, now + .24); oscillator.connect(gain).connect(audio.destination); oscillator.start(now); oscillator.stop(now + .25); }

  function currentChunk() { return chunks.findLast(chunk => chunk.origin / 50 <= cameraX + 4) || chunks[0]; }
  function scene(shaderTime) { const objects = [], visible = chunks.filter(chunk => Math.abs(chunk.origin / 50 + 9 - cameraX) < 45); for (let i = 0; i < visible.length; i++) { const chunk = visible[i], next = chunks.find(other => other.index === chunk.index + 1); addSand(objects, chunk, next); addWhales(objects, chunk); addSeaRocks(objects, chunk); addFish(objects, chunk); addHills(objects, chunk, next); addTrees(objects, chunk); addHumans(objects, chunk); addBirds(objects, chunk); addClouds(objects, chunk); }
    const active = currentChunk(), light = active.weather.light / 255, target = [cameraX + 7, 1.6, .4]; let camera; if (pov === "sea") camera = { eye: [cameraX - 2, -.4, 13], target: [cameraX + 8, -1.7, -1.5], up: [0, 1, 0], fov: 48 }; else if (pov === "sky") camera = { eye: [cameraX - 3, 8.5, 15], target: [cameraX + 8, 6.3, 0], up: [0, 1, 0], fov: 48 }; else if (pov === "orbit") camera = orbit.camera(target); else camera = { eye: [cameraX - 4, 4.3, 17], target, up: [0, 1, 0], fov: 46 }; return { objects, camera, time: shaderTime, background: active.weather.rain === "RainHeavy" ? "#668491" : active.weather.sun === "SunBright" ? "#78c7e7" : "#91aeba", sun: { direction: [-.35, -1, -.18], color: active.weather.sun === "SunDim" ? "#9db1bd" : "#fff3ca" }, point: { position: [cameraX + 8, 10, 3], color: light > .75 ? "#ffe9b5" : "#acd8e5" }, fog: { color: active.weather.rain === "RainHeavy" ? "#748c96" : "#a9dbe8", density: .009 + active.weather.rainAmount / 15000 }, caustic: light };
  }

  function draw(time = 0) { const active = currentChunk(), stats = renderer.render(scene(time / 1000)); $("chunk").textContent = active.index.toLocaleString(); $("distance").textContent = `${Math.max(0, Math.floor(cameraX * 50)).toLocaleString()} u`; $("tide").textContent = `${active.weather.tide} · ${active.weather.tideY}`; $("weather").textContent = `${active.weather.wind} · ${active.weather.cloud} · ${active.weather.rain}`; $("sand").textContent = sandCount(active.raw.$4.$1); $("triangles").textContent = Math.round(stats.triangles).toLocaleString(); if (audio && active.index !== lastCallChunk && active.sky.birds.length) { playCall(tag(active.sky.birds[0].$2)); lastCallChunk = active.index; } }
  function loop(time) { if (playing && time - last > 16) { cameraX += .018 * speed; while (chunks.at(-1).origin / 50 < cameraX + 80) generateOne(); if (chunks.length > 18) chunks.splice(0, chunks.length - 18); last = time; } draw(time); requestAnimationFrame(loop); }
  $("generate").onclick = () => reset($("key").value); $("pause").onclick = () => { playing = !playing; $("pause").textContent = playing ? "Pause scroll" : "Continue scroll"; }; $("speed").oninput = event => { speed = Number(event.target.value); $("speedValue").textContent = `${speed.toFixed(1)}×`; }; $("pov").onchange = event => { pov = event.target.value; }; $("sound").onclick = async () => { const Context = globalThis.AudioContext || globalThis.webkitAudioContext; if (!Context) { $("sound").textContent = "Audio unavailable"; return; } audio ||= new Context(); await audio.resume(); $("sound").textContent = "Core-selected bird calls on"; }; orbit.onChange(() => { if (pov === "orbit") draw(performance.now()); });
  reset(731); requestAnimationFrame(loop); globalThis.BEND_LANDSCAPE_VIEWER = { reset, generateOne, get chunks() { return chunks; }, get boundary() { return boundary; } };
})();
