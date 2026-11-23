(() => {
  "use strict";
  const E = globalThis.BEND_ENGINE_WEBGL, Core = globalThis.BENDY_BIRDS_DATA_CORE;
  const raw = globalThis.BENDY_BIRDS_DATA, $ = id => document.getElementById(id);
  const list = value => { const out = []; while (value?.$ === "Con") { out.push(value.$0); value = value.$1; } return out; };
  const names = ["jello", "rubber", "furball", "stone", "bubble", "spring"];
  const nameFromTag = { JelloBird: "jello", RubberBird: "rubber", FurballBird: "furball", StoneBird: "stone", BubbleBird: "bubble", SpringBird: "spring" };
  const blockStyle = {
    WoodBlock: ["#ad7138", "#4f2f1e", 2, .76, 0, 1], GlassBlock: ["#b7f5ff", "#42b5d8", 2, .1, .16, .42],
    IceBlock: ["#e5ffff", "#65c8e5", 3, .15, .08, .68], BrickBlock: ["#b94e3e", "#572329", 1, .9, 0, 1],
    MetalBlock: ["#aab8bd", "#34454d", 2, .2, .88, 1], JellyBlock: ["#e86afa", "#5d2477", 3, .24, .04, .78],
    BambooBlock: ["#a7cc59", "#38542a", 2, .68, 0, 1]
  };
  const parseBlock = block => ({ raw: block, id: Number(block.$0), material: block.$1.$, x: block.$2, y: block.$3, z: block.$4, w: block.$5, h: block.$6, status: block.$7.$, integrity: Number(block.$7.$0 || 0n) });
  const parseFrame = frame => ({ tick: frame.$0, x: frame.$1, y: frame.$2, rotation: frame.$3, squash: frame.$4, stretch: frame.$5, trail: frame.$6 });
  const parseShot = result => ({ raw: result, kind: nameFromTag[result.$0.$], angle: Number(result.$1), strength: Number(result.$2), frames: list(result.$3).map(parseFrame), rawBlocks: result.$4, blocks: list(result.$4).map(parseBlock), score: Number(result.$5), shot: Number(result.$6) });
  const canvas = $("game"), renderer = E.create(canvas), orbit = E.bindOrbit(canvas, { yaw: .15, pitch: .18, distance: 14, target: [1.5, 2, 0] });
  let currentBlocks = raw.$2, beforeBlocks = list(currentBlocks).map(parseBlock), chosen = parseShot(list(raw.$3)[0]);
  let index = 0, playing = false, last = 0, shotNumber = 0;

  const corePosition = frame => [frame.x / 150 - 5.4, Math.max(.72, frame.y / 150 - .05), 0];
  function addBlock(out, block, broken) {
    const style = blockStyle[block.material] || blockStyle.WoodBlock, x = block.x / 150 - 5.5, y = block.y / 150, z = block.z / 150;
    if (broken) {
      const debrisKind = block.material === "WoodBlock" || block.material === "BambooBlock" ? "branch" : block.material === "JellyBlock" ? "capsule" : "shard";
      for (let i = 0; i < 11; i++) out.push(E.part(debrisKind, [x + (i % 4 - 1.5) * .22, .12 + Math.floor(i / 4) * .11, z + Math.sin(i * 2.1) * .28], [block.w / 860, block.h / 1900, block.w / 920], style[0], { color2: style[1], texture: style[2], roughness: style[3], metallic: style[4], alpha: style[5], rot: [i * .47, i * .83, i * .61], rim: block.material === "GlassBlock" || block.material === "IceBlock" ? .28 : 0 }));
      return;
    }
    const scale = [block.w / 300, block.h / 300, .38], common = { color2: style[1], texture: style[2], roughness: style[3], metallic: style[4], alpha: style[5] };
    if (block.material === "BambooBlock") {
      for (let pole = -2; pole <= 2; pole++) out.push(E.part("branch", [x + pole * scale[0] * .34, y, z], [scale[0] * .22, scale[1], .16], style[0], { ...common, rot: [0, pole * .13, pole * .035], wind: .035, phase: block.id + pole }));
      for (const offset of [-.52, .52]) out.push(E.part("torus", [x, y + offset * scale[1], z], [scale[0] * .78, .055, .31], style[1], { rot: [0, 0, Math.PI / 2], roughness: .72 }));
    } else if (block.material === "JellyBlock") {
      out.push(E.part("capsule", [x, y, z], scale, style[0], { ...common, soft: .24, pulse: .08, phase: block.id, rim: .25, subsurface: .25 }));
      for (let bead = 0; bead < 5; bead++) out.push(E.part("torus", [x, y + (bead / 4 - .5) * scale[1] * 1.45, z], [scale[0] * .72, .035, .3], style[1], { alpha: .34, rot: [0, 0, Math.PI / 2] }));
    } else if (block.material === "GlassBlock" || block.material === "IceBlock") {
      out.push(E.part("bevel", [x, y, z], scale, style[0], { ...common, rim: .38, subsurface: .18 }));
      for (const side of [-1, 1]) out.push(E.part("crystal", [x + side * scale[0] * .72, y, z], [.08, scale[1] * .72, .09], style[1], { alpha: style[5], metallic: .2, rim: .4 }));
    } else {
      out.push(E.part("bevel", [x, y, z], scale, style[0], common));
      if (block.material === "BrickBlock") for (let course = -1; course <= 1; course++) out.push(E.part("rope", [x, y + course * scale[1] * .48, z + .37], [scale[0], .045, .04], style[1], { roughness: .95 }));
      if (block.material === "MetalBlock") for (const side of [-1, 1]) out.push(E.part("torus", [x + side * scale[0] * .62, y, z + .39], [.07, .025, .07], "#e7f0f1", { metallic: .95, roughness: .08, rot: [Math.PI / 2, 0, 0] }));
    }
  }

  function objects(frame, time) {
    const out = [
      E.part("island", [1.5, -.42, 0], [8.4, .72, 3.5], "#78b94d", { color2: "#334d29", texture: 3, roughness: .92 }),
      E.part("branch", [-4.58, .82, -.45], [.22, 1.24, .22], "#743d24", { rot: [0, 0, -.18], roughness: .9 }),
      E.part("branch", [-4.58, .82, .45], [.22, 1.24, .22], "#743d24", { rot: [0, Math.PI, .18], roughness: .9 }),
      E.part("rope", [-4.56, 1.52, 0], [.62, .75, .7], "#30201b", { rot: [0, Math.PI / 2, 0], roughness: .76 }),
      E.part("torus", [-4.56, .18, 0], [.66, .08, .66], "#5d321f", { roughness: .86 })
    ];
    out.push(...E.tree("oak", [-1.9, 0, 2.05], .58, time + 1, ["#70462c", "#438b43"]), ...E.tree("pine", [5.8, 0, 2.3], .72, time + 4, ["#69432d", "#285f42"]));
    for (let rock = 0; rock < 9; rock++) out.push(E.part("rock", [-2.7 + rock * 1.15, .02, -2.5 + Math.sin(rock * 2.2) * .32], [.24 + rock % 3 * .08, .18, .3], rock % 2 ? "#596452" : "#6e765d", { roughness: .95, rot: [rock, rock * .6, 0] }));
    const impactVisible = index >= chosen.frames.length - 8;
    const active = impactVisible ? chosen.blocks : beforeBlocks;
    for (const block of active) addBlock(out, block, block.status === "Broken");
    const position = corePosition(frame), deform = Math.min(.42, frame.squash / 240);
    out.push(...E.bird(chosen.kind, position, deform, time + frame.tick * .06));
    for (let i = 1; i < Math.min(18, Number(frame.trail) + 7); i++) out.push(E.part(i % 3 ? "star" : "torus", [position[0] - i * .12, position[1] + Math.sin(i * .8) * .035, position[2]], [.075 - i * .0025, .028, .075 - i * .0025], chosen.kind === "bubble" ? "#8eefff" : chosen.kind === "furball" ? "#dbb6ff" : "#fff2c8", { alpha: .28 - i * .01, roughness: .1, emissive: .14, rot: [Math.PI / 2, time * 2 + i, 0] }));
    if (impactVisible) for (let i = 0; i < 18; i++) out.push(E.part(i % 2 ? "shard" : "star", [position[0] + Math.cos(i) * i * .035, .3 + Math.sin(i * 2.2) * .18, Math.sin(i) * .5], [.045, .08 + i % 3 * .03, .045], "#ffe19a", { alpha: .5, emissive: .25, rot: [i, time * 2 + i, i * .4] }));
    return out;
  }

  function draw(time = 0) {
    const frame = chosen.frames[index];
    const stats = renderer.render({ objects: objects(frame, time / 1000), camera: orbit.camera([1.5, 1.7, 0]), time: time / 1000, background: "#92cfeb", sun: { direction: [-.45, -1, -.2], color: "#fff0c8" }, point: { position: [0, 7, 4], color: "#ffb17a" }, fog: { color: "#b8d9e3", density: .01 } });
    $("frame").textContent = `${index + 1}/${chosen.frames.length}`;
    $("score").textContent = chosen.score; $("triangles").textContent = Math.round(stats.triangles).toLocaleString();
    $("material").textContent = chosen.kind;
    const broken = chosen.blocks.filter(block => block.status === "Broken").length;
    $("state").textContent = index === chosen.frames.length - 1 ? `${broken} total structures destroyed` : "Core parabolic soft-body flight";
  }

  function loop(time) {
    if (playing && time - last > 36) { index++; last = time; if (index >= chosen.frames.length) { index = chosen.frames.length - 1; playing = false; currentBlocks = chosen.rawBlocks; shotNumber = chosen.shot; } }
    draw(time); requestAnimationFrame(loop);
  }

  function launch() {
    const code = Math.max(0, names.indexOf($("bird").value)), angle = Number($("angle").value), strength = Number($("power").value);
    beforeBlocks = list(currentBlocks).map(parseBlock);
    chosen = parseShot(Core.shot(code, angle, strength, currentBlocks, shotNumber));
    $("actual").textContent = `Core result ${chosen.kind} · exact ${chosen.angle}° · power ${chosen.strength} · impact x ${chosen.frames.at(-1).x}`;
    index = 0; playing = true;
  }
  $("launch").onclick = launch;
  $("reset").onclick = () => { currentBlocks = raw.$2; beforeBlocks = list(currentBlocks).map(parseBlock); shotNumber = 0; launch(); };
  $("angle").oninput = event => $("angle-value").textContent = `${event.target.value}°`;
  $("power").oninput = event => $("power-value").textContent = event.target.value;
  orbit.onChange(() => draw(performance.now()));
  requestAnimationFrame(loop);
  globalThis.BENDY_BIRDS_VIEWER = { launch, get shot() { return chosen; }, get blocks() { return currentBlocks; } };
})();
