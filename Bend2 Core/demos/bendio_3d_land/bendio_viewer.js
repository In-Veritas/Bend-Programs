(() => {
  "use strict";
  const E = globalThis.BEND_ENGINE_WEBGL;
  const Core = globalThis.BENDIO_DATA_CORE;
  const $ = id => document.getElementById(id);
  const list = value => {
    const out = [];
    while (value?.$ === "Con") { out.push(value.$0); value = value.$1; }
    return out;
  };
  const n = value => Number(value);
  const palettes = {
    GrassStone: ["#62cd65", "#235c3b", 3],
    GoldenBrick: ["#f6cc46", "#8d4f25", 1],
    CloudGlass: ["#dffbff", "#68b8e9", 2],
    LavaRock: ["#372b39", "#ff5d29", 2],
    MossRuins: ["#789864", "#384a37", 3],
    CrystalTile: ["#a9d9ff", "#865be7", 2]
  };
  const canvas = $("game");
  const renderer = E.create(canvas);
  const orbit = E.bindOrbit(canvas, { yaw: .7, pitch: .28, distance: 15, target: [0, 2, 0] });
  let report, platforms, segments, frames, index = 0, playing = true, finished = false, last = 0, pov = "director";

  const worldPosition = frame => [n(frame.$1) / 300 - 1.5, n(frame.$2) / 300, n(frame.$3) / 300 - 1.8];
  const platformWorld = platform => ({
    id: n(platform.$0), x: n(platform.$1) / 300 - 1.5,
    y: n(platform.$2) / 300, z: n(platform.$3) / 300 - 1.8,
    w: n(platform.$4) / 300, h: n(platform.$5) / 300,
    d: n(platform.$6) / 300, material: platform.$7.$
  });

  function acceptReport(value) {
    report = value;
    platforms = list(value.$2).map(platformWorld);
    segments = list(value.$3);
    frames = segments.flatMap(segment => list(segment.$4));
    index = 0; finished = false; playing = true; last = 0;
    $("seed").value = n(value.$1);
    $("timeline").max = Math.max(0, frames.length - 1);
    $("timeline").value = 0;
    $("play").textContent = "Pause NPC";
    $("levelStats").textContent = `${platforms.length} platforms · ${segments.length} exact jumps`;
  }

  function camera(frame) {
    const hero = worldPosition(frame);
    if (pov === "chase") return { eye: [hero[0] - 4.5, hero[1] + 2.5, hero[2] + 4.8], target: [hero[0] + 2.5, hero[1] + .8, hero[2]], up: [0, 1, 0], fov: 52 };
    if (pov === "side") return { eye: [hero[0], hero[1] + 3.1, hero[2] + 11], target: [hero[0] + .6, hero[1] + .8, hero[2]], up: [0, 1, 0], fov: 44 };
    if (pov === "first") return { eye: [hero[0] + .18, hero[1] + 1.8, hero[2] + .15], target: [hero[0] + 6, hero[1] + 1.35, hero[2]], up: [0, 1, 0], fov: 66 };
    if (pov === "orbit") return orbit.camera(hero);
    return { eye: [hero[0] - 6.5, hero[1] + 5.8, hero[2] + 8.5], target: [hero[0] + 3.1, hero[1] + .65, hero[2]], up: [0, 1, 0], fov: 49 };
  }

  function addPlatform(objects, p, time) {
    const palette = palettes[p.material] || palettes.GrassStone;
    const glass = p.material === "CloudGlass" || p.material === "CrystalTile";
    const bodyHeight = Math.max(.42, p.h * .72);
    objects.push(E.part("island", [p.x, p.y - bodyHeight * .42, p.z], [p.w * .56, bodyHeight, p.d * .58], palette[0], {
      color2: palette[1], texture: palette[2], roughness: glass ? .14 : .7,
      metallic: p.material === "GoldenBrick" ? .28 : p.material === "CrystalTile" ? .42 : .03,
      alpha: p.material === "CloudGlass" ? .82 : 1,
      rim: glass ? .22 : .03
    }));
    const count = 3 + p.id % 4;
    for (let edge = 0; edge < 7; edge++) {
      const angle = edge / 7 * Math.PI * 2;
      objects.push(E.part("rock", [p.x + Math.cos(angle) * p.w * .46, p.y - .08, p.z + Math.sin(angle) * p.d * .44], [.22 + edge % 3 * .06, .18 + edge % 2 * .08, .2 + edge % 4 * .035], palette[1], { texture: 3, roughness: .92, rot: [edge * .17, edge * .73, 0] }));
    }
    if (p.material === "GrassStone") {
      for (let i = 0; i < Math.min(3, count); i++) {
        const dx = ((i + 1) / 4 - .5) * p.w * .72, treeSize = .38 + ((p.id * 5 + i * 3) % 8) / 20;
        objects.push(...E.tree(i % 2 ? "oak" : "pine", [p.x + dx, p.y, p.z + ((i % 3) - 1) * p.d * .2], treeSize, time + p.id + i, ["#75472b", i % 2 ? "#4bc55a" : "#27794c"]));
      }
    } else if (p.material === "MossRuins") {
      objects.push(E.part("arch", [p.x, p.y + .66, p.z], [1.05, 1.15, .58], "#879677", { color2: "#334838", texture: 3, roughness: .91, rot: [0, p.id * .47, 0] }));
      for (let i = 0; i < 5; i++) objects.push(E.part("leaf", [p.x + (i - 2) * .28, p.y + .55 + i % 2 * .24, p.z + .33], [.12, .3, .16], i % 2 ? "#8ac45f" : "#3b7b4b", { rot: [i * .4, p.id, .6], doubleSided: true, wind: .2, phase: time + i }));
    } else if (p.material === "LavaRock") {
      for (let i = 0; i < count + 2; i++) objects.push(E.part(i % 2 ? "shard" : "crystal", [p.x + (i / (count + 1) - .45) * p.w, p.y + .25 + i % 2 * .12, p.z + ((i % 3) - 1) * .42], [.16, .35 + i % 3 * .13, .16], i % 2 ? "#ff8b39" : "#7e2940", { metallic: .18, emissive: .42, rim: .25, phase: time + i, pulse: .08 }));
    } else if (p.material === "GoldenBrick") {
      objects.push(E.part("arch", [p.x, p.y + .68, p.z], [1.08, 1.2, .58], "#f6d365", { color2: "#9d5725", texture: 7, metallic: .48, roughness: .24 }));
      for (let i = 0; i < count; i++) objects.push(E.part("star", [p.x + (i / count - .42) * p.w, p.y + .34 + Math.sin(time * 1.4 + i) * .07, p.z], [.16, .08, .16], "#fff079", { metallic: .68, emissive: .16, rot: [Math.PI / 2, time + i, 0] }));
    } else if (p.material === "CloudGlass") {
      objects.push(...E.cloud([p.x, p.y + .18, p.z], Math.min(1.2, p.w * .13), "#e7fbff", time + p.id, .58));
      for (let i = 0; i < 3; i++) objects.push(E.part("crystal", [p.x + (i - 1) * .62, p.y + .32, p.z], [.13, .28 + i * .08, .13], i % 2 ? "#73c8f4" : "#d8fbff", { alpha: .72, rim: .36, metallic: .2 }));
    } else {
      for (let i = 0; i < count + 1; i++) objects.push(E.part("crystal", [p.x + (i / count - .5) * p.w * .8, p.y + .3, p.z + Math.sin(i * 2.3) * .3], [.15, .34 + i % 3 * .13, .15], i % 2 ? palette[0] : palette[1], { metallic: .52, roughness: .09, alpha: .9, rim: .35, emissive: .12, pulse: .05, phase: time + i }));
    }
    objects.push(E.part("torus", [p.x, p.y + .035, p.z], [Math.min(.7, p.w * .16), .035, Math.min(.7, p.d * .22)], "#fff3a0", { alpha: .2, metallic: .8, emissive: .08, rot: [0, time * .12, 0] }));
  }

  function scene(frame, time) {
    const objects = [];
    const hero = worldPosition(frame);
    for (const platform of platforms) if (Math.abs(platform.x - hero[0]) < 22) addPlatform(objects, platform, time);
    for (let i = 0; i < segments.length; i++) {
      const a = segments[i].$0, b = segments[i].$1;
      const ax = n(a.$1) / 300 - 1.5, bx = n(b.$1) / 300 - 1.5;
      if (Math.abs((ax + bx) * .5 - hero[0]) > 18) continue;
      for (let c = 1; c <= 4; c++) {
        const t = c / 5, x = ax + (bx - ax) * t;
        const y = (n(a.$2) + (n(b.$2) - n(a.$2)) * t) / 300 + 1.02 + Math.sin(Math.PI * t) * 1.35;
        const z = (n(a.$3) + (n(b.$3) - n(a.$3)) * t) / 300 - 1.8;
        objects.push(E.part("torus", [x, y, z], [.2, .2, .2], "#ffe35e", { metallic: .82, roughness: .12, emissive: .14, rot: [Math.PI / 2, time * 1.7 + c, 0] }));
        objects.push(E.part("star", [x, y, z], [.09, .035, .09], "#fff7b0", { metallic: .62, emissive: .24, rot: [Math.PI / 2, -time * 1.1 - c, 0] }));
      }
    }
    objects.push(...E.hero(hero, n(frame.$4) * .12));
    objects.push(E.part("disc", [hero[0], .015, hero[2]], [.58, .02, .32], "#173454", { alpha: .22 }));
    return {
      objects, camera: camera(frame), time, background: "#74c7ed",
      sun: { direction: [-.42, -1, -.3], color: "#fff4c8" },
      point: { position: [hero[0] + 2, hero[1] + 5, hero[2] + 3], color: "#8ddfff" },
      fog: { color: "#b6e4f2", density: .013 }
    };
  }

  function draw(time = 0) {
    const frame = frames[index];
    const stats = renderer.render(scene(frame, time / 1000));
    const segment = Math.min(segments.length - 1, Math.floor(index / 36));
    $("frame").textContent = `${index + 1} / ${frames.length}`;
    $("segment").textContent = `${segment + 1} / ${segments.length}`;
    $("action").textContent = n(frame.$5) === 2 ? "Takeoff" : n(frame.$5) === 3 ? "Landing" : "Airborne";
    $("coins").textContent = n(frame.$6);
    $("triangles").textContent = Math.round(stats.triangles).toLocaleString();
    $("timeline").value = index;
  }

  function loop(time) {
    if (playing && !finished && time - last > 48) {
      if (index < frames.length - 1) index++;
      else { finished = true; playing = false; $("play").textContent = "Replay level"; }
      last = time;
    }
    draw(time);
    requestAnimationFrame(loop);
  }

  $("generate").onclick = () => {
    const seed = Math.max(0, Math.min(4294967295, Number($("seed").value) || 0));
    acceptReport(Core.level(seed));
  };
  $("play").onclick = () => {
    if (finished) { index = 0; finished = false; playing = true; }
    else playing = !playing;
    $("play").textContent = playing ? "Pause NPC" : "Play NPC";
  };
  $("timeline").oninput = event => { index = +event.target.value; playing = false; finished = index === frames.length - 1; $("play").textContent = finished ? "Replay level" : "Play NPC"; };
  $("pov").onchange = event => { pov = event.target.value; };
  orbit.onChange(() => { if (pov === "orbit") draw(performance.now()); });
  acceptReport(globalThis.BENDIO_DATA);
  requestAnimationFrame(loop);
  globalThis.BENDIO_VIEWER = { get report() { return report; }, get frames() { return frames; }, get platforms() { return platforms; }, generate: seed => acceptReport(Core.level(seed)) };
})();
