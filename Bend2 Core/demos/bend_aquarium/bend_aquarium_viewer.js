(() => {
  "use strict";
  const E = globalThis.BEND_ENGINE_WEBGL, Core = globalThis.BEND_AQUARIUM_DATA_CORE, raw = globalThis.BEND_AQUARIUM_DATA, $ = id => document.getElementById(id);
  const list = value => { const out = []; while (value?.$ === "Con") { out.push(value.$0); value = value.$1; } return out; };
  const fishKinds = ["Clownfish", "BlueTang", "MoorishIdol", "RoyalGramma", "MandarinDragonet", "Butterflyfish", "Angelfish", "Firefish", "Chromis", "YellowTang", "CleanerWrasse", "Cardinalfish"];
  const fishPalettes = {
    Clownfish: ["#ff7b24", "#fff7df"], BlueTang: ["#176be8", "#ffe236"], MoorishIdol: ["#fff8d7", "#151823"],
    RoyalGramma: ["#8d42e8", "#ffdf3f"], MandarinDragonet: ["#36e0c7", "#f15b25"], Butterflyfish: ["#ffe04b", "#32294f"],
    Angelfish: ["#6de5f0", "#352570"], Firefish: ["#fff6df", "#ef3e52"], Chromis: ["#42cde7", "#2969a4"],
    YellowTang: ["#ffdf22", "#f69d18"], CleanerWrasse: ["#2c76e8", "#161c42"], Cardinalfish: ["#ef5868", "#fff4d5"]
  };
  const coralKinds = ["EuphylliaParancora", "EuphylliaGlabrescens", "EuphylliaAncora", "CoralliumRubrum", "AcroporaBranch", "BrainCoral", "PlateCoral", "Anemone"];
  const fishes = list(raw.$2).map(value => ({ id: Number(value.$0), tag: value.$1.$, kind: fishKinds.indexOf(value.$1.$), x: Number(value.$2), y: Number(value.$3), z: Number(value.$4), size: Number(value.$5), pattern: Number(value.$8) }));
  const corals = list(raw.$3).map(value => ({ id: Number(value.$0), tag: value.$1.$, kind: coralKinds.indexOf(value.$1.$), x: Number(value.$2), y: Number(value.$3), z: Number(value.$4), size: Number(value.$5), color: Number(value.$6), polyps: Number(value.$7), sway: Number(value.$8), fluorescence: Number(value.$9) }));
  const equipment = { bubblers: Number(raw.$4.$0), filter: Number(raw.$4.$1), lightWidth: Number(raw.$4.$2), light: Number(raw.$4.$3), jets: Number(raw.$4.$4) };
  const parseFrame = value => ({ tick: Number(value.$0), currentX: Number(value.$1), currentZ: Number(value.$2), wave: Number(value.$3), bubbles: Number(value.$4), caustics: Number(value.$5), refraction: Number(value.$6), filter: Number(value.$7), phase: Number(value.$8) });
  const fixtureFrames = list(raw.$5).map(parseFrame);
  const canvas = $("game"), renderer = E.create(canvas), orbit = E.bindOrbit(canvas, { yaw: .62, pitch: .22, distance: 15, target: [0, 2.2, 0] });
  let tick = 0, frame = parseFrame(Core.frame(0, 91)), paused = false, last = 0;

  const polypColor = coral => `hsl(${(coral.color / 255) * 340} 84% ${48 + coral.fluorescence / 18}%)`;
  function coralParts(coral, f) {
    const out = [], base = [coral.x / 270 - 5.2, .05, coral.z / 260 - 2.5], size = coral.size / 190;
    const phase = (f.phase + coral.id * 29) / 360 * Math.PI * 2, current = ((f.currentX + f.currentZ) / 350 - .45) * coral.sway / 255;
    const sway = Math.sin(phase) * coral.sway / 255 * .32 + current * .22, color = polypColor(coral), dark = coral.tag === "CoralliumRubrum" ? "#8b102e" : "#526c51";
    out.push(...E.coral(coral.tag, base, size, color, phase));
    if (coral.tag === "EuphylliaParancora") {
      for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2, r = (i % 4) * .1 * size, h = (.5 + (i % 5) * .08) * size, tip = [base[0] + Math.cos(a) * r + sway * h, base[1] + h, base[2] + Math.sin(a) * r]; out.push(E.part("capsule", tip, [.17 * size, .075 * size, .12 * size], color, { color2: "#d7ff9a", texture: 2, soft: .1, rim: .16, rot: [0, a, Math.PI / 2] })); }
    } else if (coral.tag === "EuphylliaGlabrescens") {
      for (let i = 0; i < 16; i++) { const a = i / 16 * Math.PI * 2, r = .08 + (i % 5) * .055, h = (.72 + (i % 4) * .1) * size; out.push(E.part("star", [base[0] + Math.cos(a) * r + sway * h, base[1] + h, base[2] + Math.sin(a) * r], [.07 * size, .025 * size, .07 * size], "#cfff9b", { metallic: .15, emissive: .2, rot: [Math.PI / 2, a + phase, 0] })); }
    } else if (coral.tag === "EuphylliaAncora") {
      for (let i = 0; i < 9; i++) { const u = i / 8 - .5, h = (.52 + .12 * Math.cos(u * Math.PI * 2)) * size; out.push(E.part("leaf", [base[0] + u * size * 1.2 + sway * h, base[1] + h * .72, base[2]], [.1 * size, .25 * size, .16 * size], i % 2 ? color : "#ddffb6", { rot: [0, i * .2, Math.PI / 2 - sway], doubleSided: true, wind: .16, phase: phase + i, subsurface: .25 })); }
    } else if (coral.tag === "CoralliumRubrum") {
      for (let i = 0; i < 14; i++) { const a = (i / 14 - .5) * 2.5, h = (.42 + (i % 6) * .1) * size, x = base[0] + Math.sin(a) * size * .34; for (let p = 0; p < 3; p++) out.push(E.part("star", [x + (p - 1) * .055, base[1] + h * (.48 + p * .2), base[2]], [.035, .018, .035], p % 2 ? "#fff0df" : dark, { emissive: .14, rot: [Math.PI / 2, a + p, 0] })); }
    } else if (coral.tag === "AcroporaBranch") {
      for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2, r = (i % 4) * .12 * size, h = (.5 + i % 5 * .11) * size; out.push(E.part("star", [base[0] + Math.cos(a) * r, base[1] + h, base[2] + Math.sin(a) * r], [.06 * size, .025 * size, .06 * size], "#f8e6cf", { emissive: .1, rot: [Math.PI / 2, a, 0] })); }
    } else if (coral.tag === "BrainCoral") for (let ridge = 0; ridge < 4; ridge++) out.push(E.part("torus", [base[0], base[1] + size * (.3 + ridge * .055), base[2]], [size * (.6 - ridge * .09), size * .12, size * (.6 - ridge * .09)], ridge % 2 ? color : "#603b74", { roughness: .82, twist: .08 }));
    return out;
  }

  function aquariumDetails(out, phase) {
    out.push(E.part("arch", [-1.05, .62, -.45], [1.05, 1.05, .72], "#53635e", { color2: "#263c38", texture: 3, roughness: .94, rot: [0, .28, 0] }));
    for (let rock = 0; rock < 15; rock++) out.push(E.part("rock", [-4.8 + rock * .68, .08 + rock % 3 * .035, -1.8 + Math.sin(rock * 2.4) * .32], [.18 + rock % 4 * .07, .13 + rock % 2 * .06, .22], rock % 2 ? "#596761" : "#716f63", { texture: 3, roughness: .96, rot: [rock * .3, rock * .9, 0] }));
    for (let kelp = 0; kelp < 9; kelp++) { const x = -4.4 + kelp * 1.05, z = kelp % 2 ? 1.75 : -1.65; out.push(E.part("leaf", [x, .72, z], [.2, .78 + kelp % 3 * .15, .3], kelp % 2 ? "#4a9d58" : "#287e5b", { rot: [0, kelp * .6, 0], doubleSided: true, wind: .38, phase: phase + kelp, subsurface: .18 })); }
    for (let shell = 0; shell < 7; shell++) out.push(E.part("torus", [-3.7 + shell * 1.15, .13, .85 + Math.sin(shell) * .4], [.16, .09, .16], shell % 2 ? "#f1c7a0" : "#d9948e", { rot: [.3, shell, .15], roughness: .55 }));
  }

  function scene(f, shaderTime) {
    const out = [], W = 5.6, H = 4.2, D = 2.35, phase = f.phase / 360 * Math.PI * 2;
    out.push(E.part("island", [0, -.55, 0], [W * 1.05, .48, D * 1.08], "#d7c99b", { color2: "#6f6547", texture: 3, roughness: .9 }));
    aquariumDetails(out, phase);
    for (const coral of corals) out.push(...coralParts(coral, f));
    for (const fish of fishes) {
      const p = [fish.x / 280 - 5 + Math.sin(phase + fish.id * 1.7) * (.34 + f.currentX / 900), .45 + fish.y / 350 + Math.sin(phase * 1.7 + fish.id) * .18, fish.z / 260 - 2.45 + Math.cos(phase + fish.id) * (.28 + f.currentZ / 1000)];
      const heading = phase + fish.id * .53, palette = fishPalettes[fish.tag];
      out.push(...E.fish(fish.kind, p, fish.size / 95, heading, phase * 1.5 + fish.id, palette));
      out.push(E.part("disc", [p[0], .045, p[2]], [fish.size / 120, .012, fish.size / 190], "#06131d", { alpha: Math.max(.08, .32 - p[1] * .055) }));
    }
    for (let emitter = 0; emitter < equipment.bubblers; emitter++) for (let i = 0; i < 46; i++) { const q = ((i * 17 + f.tick * (2 + emitter)) % 230) / 230, x = -3.1 + emitter * 6.2 + Math.sin((i + f.phase) * .33) * .14, y = .15 + q * 3.75, z = .7 * Math.sin(i * .87 + phase); out.push(E.part("sphere", [x, y, z], [.025 + i % 5 * .012, .025 + i % 5 * .012, .025 + i % 5 * .012], "#d9ffff", { alpha: .3 + i % 4 * .1, roughness: .02, metallic: .15 })); }
    for (let i = 0; i < equipment.jets * 9; i++) { const side = i < 9 ? -1 : 1, x = side * 5.05, y = 2.15 + i % 9 * .1, z = -1.4 + i % 5 * .65; out.push(E.part("cylinder", [x - side * (.5 + i % 3 * .32), y, z], [.018, .55 + i % 3 * .3, .018], "#77e5ed", { alpha: .16, rot: [0, 0, Math.PI / 2], soft: .08 })); }
    out.push(E.part("bevel", [5.25, 2, 0], [.28, 1.4, 1.4], "#253945", { metallic: .65, roughness: .25 }), E.part("branch", [4.65, 3.45, 0], [.09, .65, .09], "#7fcbd2", { rot: [0, 0, Math.PI / 2], metallic: .45 }));
    out.push(E.part("bevel", [0, 5.05, 0], [3.8, .2, .92], "#f5ffff", { color2: "#70dfff", texture: 7, metallic: .72, roughness: .045 }), E.part("bevel", [0, 4.72, 0], [3.45, .04, .76], "#d8ffff", { alpha: .88, metallic: .35, roughness: .015, emissive: .32 }));
    for (let i = 0; i < 7; i++) out.push(E.part("torus", [-3 + i, .052, 0], [.72, .012, 1.7], "#70e5f0", { alpha: .09 + i % 2 * .035, emissive: .08 }));
    out.push(E.part("water", [0, 3.78, 0], [W, 1, D], "#117d9c", { color2: "#75e8e5", alpha: .36, wave: f.wave / 180, roughness: .028, metallic: .18, caustic: f.caustics / 255 }));
    const glass = { color: "#bcefff", color2: "#4eaec4", alpha: .13, roughness: .025, metallic: .12 };
    out.push(E.part("box", [0, 2, -D], [W, H / 2, .035], glass.color, glass), E.part("box", [0, 2, D], [W, H / 2, .035], glass.color, glass), E.part("box", [-W, 2, 0], [.035, H / 2, D], glass.color, glass), E.part("box", [W, 2, 0], [.035, H / 2, D], glass.color, glass));
    return { objects: out, camera: orbit.camera([0, 2, 0]), time: shaderTime, background: "#061b26", sun: { direction: [-.2, -1, -.15], color: "#e9ffff" }, point: { position: [0, 5.35, 0], color: "#d9ffff" }, fog: { color: "#0b5268", density: .035 }, caustic: f.caustics / 255 };
  }

  function draw(time = 0) { const stats = renderer.render(scene(frame, time / 1000)); $("frame").textContent = `${tick.toLocaleString()} (Core)`; $("flow").textContent = frame.filter; $("wave").textContent = frame.wave; $("bubbles").textContent = frame.bubbles; $("triangles").textContent = Math.round(stats.triangles).toLocaleString(); $("frame-slider").value = Math.min(tick, Number($("frame-slider").max)); }
  function loop(time) { if (!paused && time - last > 55) { tick++; frame = parseFrame(Core.frame(tick, 91)); last = time; } draw(time); requestAnimationFrame(loop); }
  $("pause").onclick = () => { paused = !paused; $("pause").textContent = paused ? "Resume water" : "Pause water"; };
  $("frame-slider").max = 10000; $("frame-slider").oninput = event => { tick = +event.target.value; frame = parseFrame(Core.frame(tick, 91)); paused = true; };
  orbit.onChange(() => draw(performance.now())); requestAnimationFrame(loop);
  globalThis.BEND_AQUARIUM_VIEWER = { fishes, corals, fixtureFrames, get tick() { return tick; }, frameAt: value => parseFrame(Core.frame(value, 91)) };
})();
