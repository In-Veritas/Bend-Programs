(() => {
  "use strict";
  const E = globalThis.BEND_ENGINE_WEBGL, Core = globalThis.BEND_FISHING_DATA_CORE, $ = id => document.getElementById(id);
  const list = value => { const out = []; while (value?.$ === "Con") { out.push(value.$0); value = value.$1; } return out; };
  const species = ["RiverBass", "GoldenKoi", "BlueTuna", "MoonJelly", "ReefShark", "RibbonEel", "PufferFish", "Coelacanth", "MantaRay", "Seahorse"];
  const speciesLabel = value => value.replace(/([A-Z])/g, " $1").trim();
  const model = value => ({ raw: value, id: Number(value.$0), species: value.$1.$, kind: Math.max(0, species.indexOf(value.$1.$)), x: Number(value.$2), y: Number(value.$3), z: Number(value.$4), size: Number(value.$5), pattern: Number(value.$6), heading: Number(value.$7) });
  const activeModels = active => active.$ === "OneActiveFish" ? [model(active.$0)] : [model(active.$0), model(active.$1)];
  const waitingFrame = value => ({ tick: Number(value.$0), floatY: Number(value.$1), ripple: Number(value.$2), sink: Number(value.$3), phase: Number(value.$4), refraction: Number(value.$5), caustics: Number(value.$6) });
  const reelFrame = value => ({ tick: Number(value.$0), x: Number(value.$1), y: Number(value.$2), z: Number(value.$3), tension: Number(value.$4), ripple: Number(value.$5), splash: Number(value.$6), caught: Boolean(value.$7) });
  const parseSession = value => ({ raw: value, seed: Number(value.$0), castX: Number(value.$1), castZ: Number(value.$2), active: activeModels(value.$3), frames: list(value.$4).map(waitingFrame), biteStart: Number(value.$5), biteEnd: Number(value.$6), water: { clarity: value.$7.$0, ior: value.$7.$1, fresnel: value.$7.$2, absorption: value.$7.$3, caustics: value.$7.$4, layers: Number(value.$7.$5) } });
  const canvas = $("game"), renderer = E.create(canvas), orbit = E.bindOrbit(canvas, { yaw: .25, pitch: .42, distance: 13, target: [0, 1, 0] });
  let session = parseSession(Core.session(731, 600, 420)), nextSeed = 731, phase = "choose", frames = session.frames, index = 0, last = 0, result = "Click the water to choose a cast point; click again to reel.";
  let caughtSpecies = null, reelReport = null;

  const waterPosition = (x, y, z) => [x / 180 - 3.4, y / 360, z / 180 - 2.7];
  const castPosition = () => [session.castX / 180 - 3.4, 1.08, session.castZ / 180 - 2.7];

  function fishPosition(fish, frame) {
    const wave = Math.sin((frame.phase + fish.id * 5) / 24 * Math.PI * 2);
    return [fish.x / 180 - 3.4 + wave * .22, .72 - fish.y / 680, fish.z / 180 - 2.7 + Math.cos((frame.phase + fish.id * 3) / 24 * Math.PI * 2) * .16];
  }

  function addWaitingFish(out, frame) {
    for (const fish of session.active) {
      const p = fishPosition(fish, frame), heading = fish.heading / 360 * Math.PI * 2 + frame.phase / 24 * .18;
      out.push(...E.fish(0, p, fish.size / 105, heading, frame.phase / 24 * Math.PI * 2, ["#153b4d", "#061b2b"]));
      out.push(E.part("disc", [p[0], 1.045, p[2]], [fish.size / 95, .018, fish.size / 170], "#071f2d", { alpha: .3, roughness: 1 }));
    }
  }

  function addReeledFish(out, frame) {
    if (!caughtSpecies || !frame.caught) return;
    const kind = Math.max(0, species.indexOf(caughtSpecies)), p = waterPosition(frame.x, frame.y, frame.z);
    out.push(...E.fish(kind, p, .95, -.7 + frame.tick * .08, frame.tick * .2));
    out.push(E.segment("capsule", [p[0], p[1] + .18, p[2]], [-3.7, 3.48, .2], .014, "#f4f0d0", { roughness: .18, rim: .12 }));
    for (let i = 0; i < 18; i++) out.push(E.part(i % 3 ? "sphere" : "star", [p[0] + Math.cos(i) * frame.splash / 950, 1.05 + (i % 4) * .08, p[2] + Math.sin(i) * frame.splash / 950], i % 3 ? [.035, .06, .035] : [.055, .018, .055], "#bff9ff", { alpha: .54, emissive: .08, rot: [i, i * .4, 0] }));
  }

  function addLagoonDetails(out, time) {
    for (let plank = 0; plank < 11; plank++) {
      const z = -3.25 + plank * .65;
      out.push(E.part("bevel", [-4.8 + Math.sin(plank * 2.1) * .025, .43 + plank % 2 * .012, z], [2.15, .11, .285], plank % 3 ? "#a97947" : "#8b5d38", { color2: "#493020", texture: 2, roughness: .86, rot: [0, .008 * Math.sin(plank), .006 * Math.cos(plank)] }));
      for (const x of [-6.45, -3.3]) out.push(E.part("torus", [x, .56, z], [.055, .018, .055], "#708085", { metallic: .76, roughness: .2 }));
    }
    for (const z of [-2.85, 2.85]) out.push(E.part("branch", [-3.5, .05, z], [.2, 1.24, .2], "#5e3d27", { texture: 2, roughness: .93, rot: [0, z, 0] }));
    out.push(E.part("torus", [-5.65, .72, 2.25], [.48, .14, .48], "#7a4c2c", { rot: [.1, 0, 0], roughness: .82 }), E.part("torus", [-5.65, .89, 2.25], [.4, .12, .4], "#b27a3d", { roughness: .78 }));
    for (let patch = 0; patch < 7; patch++) {
      const side = patch % 2 ? 1 : -1, x = side * (4.25 + patch % 3 * .55), z = -3.5 + patch * 1.12;
      for (let reed = 0; reed < 4; reed++) out.push(E.part("branch", [x + reed * .09, .72 + reed % 2 * .14, z], [.025, .72 + reed % 3 * .16, .025], reed % 2 ? "#6f9d42" : "#3e733a", { wind: .22, phase: time + patch + reed, rot: [0, 0, (reed - 1.5) * .08] }));
      out.push(E.part("leaf", [x + .05, 1.25, z], [.16, .26, .22], "#91b84d", { rot: [0, patch, .7], doubleSided: true, wind: .3, phase: time + patch }));
    }
    for (let lily = 0; lily < 8; lily++) { const x = -1.9 + lily * .7, z = lily % 2 ? 3.45 : -3.55; out.push(E.part("leaf", [x, 1.075, z], [.38, .05, .42], lily % 3 ? "#4f9b57" : "#73b752", { rot: [0, lily * .78, Math.PI / 2], doubleSided: true, roughness: .72 })); if (lily % 3 === 0) out.push(E.part("star", [x, 1.13, z], [.13, .04, .13], "#f8bbd8", { emissive: .05, rot: [Math.PI / 2, lily, 0] })); }
    for (let rock = 0; rock < 12; rock++) out.push(E.part("rock", [-6.3 + rock * 1.1, .02, rock % 2 ? 4.15 : -4.15], [.36 + rock % 3 * .09, .24 + rock % 2 * .1, .44], rock % 2 ? "#60716a" : "#52605c", { texture: 3, roughness: .95, rot: [rock * .2, rock * .7, 0] }));
  }

  function scene(frame, time) {
    const out = [E.part("island", [0, -.72, 0], [7.25, .68, 5], "#c8a76b", { color2: "#665034", texture: 3, roughness: .94 })];
    addLagoonDetails(out, time);
    let ripple, caustics, floatY;
    if (phase === "reeling" || phase === "resolved") {
      ripple = frame.ripple; caustics = 190; floatY = Math.min(1.7, frame.y / 360);
      addReeledFish(out, frame);
    } else {
      ripple = frame.ripple; caustics = frame.caustics; floatY = 1.16 - frame.sink / 430;
      addWaitingFish(out, frame);
    }
    const cast = castPosition();
    const rodBase = [-5.15, 1.05, .2], rodTip = [-3.7, 3.48, .2], lineMid = [(rodTip[0] + cast[0]) * .5, Math.max(1.22, 2.05 - ripple / 900), (rodTip[2] + cast[2]) * .5];
    out.push(E.segment("branch", rodBase, rodTip, .045, "#493328", { texture: 2, roughness: .72 }), E.segment("capsule", rodTip, lineMid, .011, "#f5f2db", { roughness: .12 }), E.segment("capsule", lineMid, [cast[0], floatY + .24, cast[2]], .011, "#f5f2db", { roughness: .12 }));
    out.push(E.part("capsule", [cast[0], floatY, cast[2]], [.09, .27, .09], "#ff5a48", { color2: "#fff4d2", texture: 1, roughness: .28 }), E.part("torus", [cast[0], floatY + .03, cast[2]], [.12, .035, .12], "#fff4d2", { roughness: .22 }));
    for (let i = 0; i < session.water.layers; i++) { const radius = .32 + i * .16 + ripple / 280; out.push(E.part("torus", [cast[0], 1.045 + i * .0015, cast[2]], [radius, .018, radius], i % 2 ? "#d7ffff" : "#66d5e5", { alpha: Math.max(.025, .19 - i * .012), roughness: .05 })); }
    out.push(E.part("water", [0, 1.06, 0], [6.8, 1, 4.6], "#168cb1", { color2: "#75e7ee", alpha: .6, roughness: .055, metallic: .14, wave: .35 + ripple / 320, caustic: caustics / 255 }));
    return { objects: out, camera: orbit.camera([0, .8, 0]), time, background: "#9bd7ea", sun: { direction: [-.35, -1, -.15], color: "#fff5cd" }, point: { position: [-1, 6, 2], color: "#79dcff" }, fog: { color: "#4bb3c5", density: .024 }, caustic: caustics / 255 };
  }

  function draw(time = 0) {
    const frame = frames[index], stats = renderer.render(scene(frame, time / 1000));
    $("clock").textContent = `${(frame.tick / 20).toFixed(1)}s`;
    $("status").textContent = result; $("fish-count").textContent = session.active.length; $("triangles").textContent = Math.round(stats.triangles).toLocaleString();
    $("timing").textContent = phase === "waiting" ? (frame.sink >= 140 ? "FLOAT SUNK — REEL!" : "occult fish nearby") : phase === "reeling" ? "reeling through Core animation" : "choose another cast";
  }

  function castAt(clientX, clientY) {
    const rect = canvas.getBoundingClientRect(), px = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width)), py = Math.max(0, Math.min(1, (clientY - rect.top) / rect.height));
    const castX = Math.round(180 + px * 850), castZ = Math.round(120 + (1 - py) * 650);
    session = parseSession(Core.session(nextSeed, castX, castZ)); frames = session.frames; index = 0; phase = "waiting"; caughtSpecies = null; reelReport = null;
    result = `Core cast at (${castX}, ${castZ}); ${session.active.length} occult fish generated.`;
  }

  function reelNow() {
    if (phase !== "waiting") return;
    const rawReport = Core.reel(session.raw, index); reelReport = rawReport; frames = list(rawReport.$2).map(reelFrame); index = 0; phase = "reeling";
    caughtSpecies = rawReport.$1.$ === "Caught" ? rawReport.$1.$1.$ : null;
    result = caughtSpecies ? `Hooked ${speciesLabel(caughtSpecies)} — watch the full line-and-water animation.` : `Escaped: ${speciesLabel(rawReport.$0.$)}.`;
    nextSeed = Number(rawReport.$3.$0);
  }

  function loop(time) {
    if ((phase === "waiting" || phase === "reeling") && time - last > (phase === "reeling" ? 42 : 70)) {
      if (index < frames.length - 1) index++;
      else if (phase === "reeling") { phase = "resolved"; result = caughtSpecies ? `Caught ${speciesLabel(caughtSpecies)}. Click the water for the next 1–2-fish pool.` : "The fish escaped. Click the water to cast again."; }
      last = time;
    }
    draw(time); requestAnimationFrame(loop);
  }

  canvas.addEventListener("click", event => { if (phase === "waiting") reelNow(); else castAt(event.clientX, event.clientY); });
  $("cast").onclick = () => { phase = "choose"; frames = session.frames; index = 0; result = "Click the exact water location where you want to cast."; };
  $("reel").onclick = reelNow;
  orbit.onChange(() => draw(performance.now()));
  requestAnimationFrame(loop);
  globalThis.BEND_FISHING_VIEWER = { castAt, reelNow, get session() { return session; }, get reel() { return reelReport; } };
})();
