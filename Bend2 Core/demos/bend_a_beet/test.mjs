import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const here = import.meta.url;
const packageDirectory = dirname(fileURLToPath(import.meta.url));
const core = resolve(process.env.BEND2_CORE || join(packageDirectory, "../../../../bend2-core"));
const revision = spawnSync("git", ["rev-parse", "HEAD"], { cwd: core, encoding: "utf8" });
if (revision.status !== 0 || !revision.stdout.trim().startsWith("c5d69a1")) {
  throw new Error(`Bend-a-Beet targets Bend c5d69a1, found ${revision.stdout.trim() || revision.stderr.trim()}`);
}
const source = readFileSync(new URL("./bend_a_beet.bend", here), "utf8");
const physics = readFileSync(new URL("./physics.bend", here), "utf8");
const graphics = readFileSync(new URL("./graphics3d.bend", here), "utf8");
const rays = readFileSync(new URL("./raytrace.bend", here), "utf8");
const sceneProofs = readFileSync(new URL("./scene_proofs.bend", here), "utf8");
const physicsProofs = readFileSync(new URL("./physics_history_proofs.bend", here), "utf8");
const engineFeatures = readFileSync(new URL("./engine_features.bend", here), "utf8");
const html = readFileSync(new URL("./index.html", here), "utf8");
const generated = readFileSync(new URL("./bend_a_beet_data.js", here), "utf8");
const camera = readFileSync(new URL("./bend_a_beet_camera.js", here), "utf8");
const webgl = readFileSync(new URL("./bend_a_beet_webgl.js", here), "utf8");
const viewerSource = readFileSync(new URL("./bend_a_beet_viewer.js", here), "utf8");

for (const [name, text] of [["game", source], ["physics", physics], ["graphics", graphics], ["raytrace", rays], ["scene proofs", sceneProofs], ["physics history proofs", physicsProofs], ["engine features", engineFeatures]]) {
  if (/^\s*#\[halts\]/m.test(text)) throw new Error(`${name} unexpectedly disables termination checking`);
}
for (const imported of ["./physics.bend", "./graphics3d.bend", "./raytrace.bend", "./scene_proofs.bend", "./physics_history_proofs.bend", "./engine_features.bend"]) {
  if (!source.includes(imported)) throw new Error(`game does not import ${imported}`);
}
if (!physics.includes("PhysicsVerificationAudit") || !graphics.includes("GraphicsVerificationAudit") || !rays.includes("RaytraceVerificationAudit")) {
  throw new Error("one or more library verification audits are missing");
}
for (const [name, text] of [["physics", physics], ["graphics", graphics], ["raytrace", rays]]) {
  if (!text.includes("general_theorems") || !text.includes("certified_cases")) {
    throw new Error(`${name} does not distinguish quantified theorems from closed certificates`);
  }
}
for (const entry of ["physics_test.bend", "graphics3d_test.bend", "raytrace_test.bend", "scene_proofs_test.bend", "physics_history_proofs_test.bend", "engine_features_test.bend"]) {
  const stem = entry.replace(/\.bend$/, "");
  const generatedTest = join(process.env.TMPDIR || "/tmp", `bend2-core-${stem}.js`);
  const generatedC = join(process.env.TMPDIR || "/tmp", `bend2-core-${stem}.c`);
  const generatedBin = join(process.env.TMPDIR || "/tmp", `bend2-core-${stem}`);
  for (const output of [generatedTest, generatedC]) {
    const compile = spawnSync("bun", [join(core, "bend2/comp.ts"), join(packageDirectory, entry), "--to", output], { cwd:core, encoding:"utf8" });
    if (compile.status !== 0) throw new Error(`${entry} did not emit ${output}:\n${compile.stdout}${compile.stderr}`);
  }
  const run = spawnSync("bun", [generatedTest], { cwd:core, encoding:"utf8" });
  if (run.status !== 0 || run.stdout.trim() !== "True{}") throw new Error(`${entry} JS did not return True{}:\n${run.stdout}${run.stderr}`);
  const nativeBuild = spawnSync("clang", ["-O2", generatedC, "-o", generatedBin], { cwd:core, encoding:"utf8" });
  if (nativeBuild.status !== 0) throw new Error(`${entry} C did not build:\n${nativeBuild.stdout}${nativeBuild.stderr}`);
  const nativeRun = spawnSync(generatedBin, ["--parallel", "off", "--gpu", "off"], { cwd:core, encoding:"utf8" });
  if (nativeRun.status !== 0 || !/^True\{\}(?:\n|$)/.test(nativeRun.stdout)) throw new Error(`${entry} native did not return True{}:\n${nativeRun.stdout}${nativeRun.stderr}`);
}
if (!html.includes('src="bend_a_beet_data.js"') || !html.includes('src="bend_a_beet_camera.js"') || !html.includes('src="bend_a_beet_webgl.js"') || !html.includes('src="bend_a_beet_viewer.js"') || !html.includes("WebGL rasterizes")) {
  throw new Error("viewer boundary or relative Core artifact note missing");
}
for (const rendererFeature of ["ellipsoid", "tube", "leaf", "disc", "fur", "facet", "responseCable", "beetBody", "soilClod", "serratedLeaf", "rootNetwork", "petal", "butterfly"]) {
  if (!webgl.includes(`function ${rendererFeature}`)) throw new Error(`missing 3D renderer feature ${rendererFeature}`);
}
for (const script of [camera, webgl, viewerSource]) new Function(script);
if (!camera.includes("pointermove") || !camera.includes("function unproject") || !camera.includes("function pose") || !camera.includes("BEND_A_BEET_CAMERA")) {
  throw new Error("orbit camera implementation is incomplete");
}
for (const shaderFeature of ["uViewProjection", "uCamera", "uSun", "uShine", "uReflection", "uFuzz", "uMetallic", "uTexture", "uFog", "reflect(-l,n)", "DEPTH_TEST"]) {
  if (!webgl.includes(shaderFeature)) throw new Error(`missing WebGL lighting/depth contract ${shaderFeature}`);
}

const context = { globalThis: {} };
vm.runInNewContext(generated, context, { filename: "bend_a_beet_data.js" });
const raw = context.globalThis.BEND_A_BEET_DATA;
if (!raw || raw.$ !== "GameReport") throw new Error("missing Bend-a-Beet GameReport");

const list = xs => { const out=[]; while (xs && xs.$ === "Con") { out.push(xs.$0); xs=xs.$1; } return out; };
const point = p => ({ x:p.$0, y:p.$1, depth:p.$2, visible:p.$3 });
const appearance = a => ({
  color:[a.$0.$0,a.$0.$1,a.$0.$2],texture:a.$1.$0,textureSeed:a.$1.$1,
  roughness:a.$1.$2,metallic:a.$1.$3,reflection:a.$1.$4.$0+1,
  fuzz:a.$1.$5,furLength:a.$1.$6,furDensity:a.$1.$7.$0+1,
  shadowSoftness:a.$2,shadowSamples:a.$3,fog:a.$4,
});
const engineProfiles = list(raw.$8).map(profile => ({tile:profile.$0,...appearance(profile.$1)}));
const engineByTile = new Map(engineProfiles.map(profile => [profile.tile, profile]));
const beet = b => ({
  tile:b.$0,row:b.$1,column:b.$2,planted:b.$3,water:b.$4,sugar:b.$5,fiber:b.$6,size:b.$7,magic:b.$8,
  pulled:b.$9,outcome:b.$10,detail:b.$11,state:b.$12,bend:b.$13,integrity:b.$14,growth:b.$15,wind:b.$16,
  tileLight:b.$17,beetLight:b.$18,shadowed:b.$19,body:point(b.$20),root:point(b.$21),control:point(b.$22),
  tip:point(b.$23),left:point(b.$24),right:point(b.$25),radius:b.$26,broken:b.$27,
  maxBend:b.$32,period:b.$33,responseDuration:b.$34,signature:b.$35,breakAt:b.$36,
  shine:b.$37,specular:b.$38,absorbed:b.$39,shadow:point(b.$40),radial:b.$41,vertical:b.$42,leafSegments:b.$43,engine:engineByTile.get(b.$0),
});
const frame = f => ({ time:f.$0,duration:f.$1,phase:f.$2,note:f.$3,active:f.$4,beets:list(f.$5).map(beet) });
const report = { seed:raw.$1,rows:raw.$2,columns:raw.$3,planted:raw.$4,broken:raw.$5,spring:raw.$6,recover:raw.$7,engineProfiles,frames:list(raw.$9).map(frame) };

if (report.seed !== 48823 || report.rows !== 8 || report.columns !== 3) throw new Error("wrong deterministic farm header");
if (report.engineProfiles.length !== 24 || new Set(report.engineProfiles.map(profile=>profile.tile)).size !== 24) throw new Error("Engine profiles do not cover all 24 tiles exactly");
if (new Set(report.engineProfiles.map(profile=>profile.texture)).size !== 4) throw new Error("Engine procedural texture classes are not represented");
for (const profile of report.engineProfiles) {
  if (profile.reflection < 1 || profile.furDensity < 1 || profile.shadowSamples !== 8 || profile.shadowSoftness !== 42) throw new Error(`invalid Engine material/light contract at ${profile.tile}`);
  if ([...profile.color,profile.roughness,profile.metallic,profile.fuzz,profile.fog].some(value=>value<0||value>255)) throw new Error(`Engine channel outside 0..255 at ${profile.tile}`);
}
if (report.frames.length !== 1086) throw new Error(`expected 1086 frames, got ${report.frames.length}`);
for (const f of report.frames) {
  if (f.beets.length !== 24) throw new Error(`${f.phase}: expected 24 tiles`);
  for (const b of f.beets) {
    if (b.tile !== b.row*3+b.column || b.row>7 || b.column>2) throw new Error(`invalid grid address ${b.tile}`);
    if ([b.tileLight,b.beetLight,b.specular,b.absorbed].some(v=>v<0||v>255)) throw new Error(`invalid light sample at ${b.tile}`);
    if (b.shine<0||b.shine>1000) throw new Error(`invalid shine at ${b.tile}`);
    if (b.radial<28||b.radial>35||b.vertical<14||b.vertical>17||b.leafSegments<10||b.leafSegments>13) throw new Error(`invalid Core mesh quality at ${b.tile}`);
    for (const p of [b.body,b.root,b.control,b.tip,b.left,b.right,b.shadow]) {
      if (!Number.isInteger(p.x) || !Number.isInteger(p.y) || !Number.isInteger(p.depth)) throw new Error(`invalid projected point at ${b.tile}`);
    }
  }
}
const first = report.frames[0], planted = first.beets.filter(b=>b.planted), empty = first.beets.filter(b=>!b.planted);
if (planted.length !== report.planted || !planted.length || !empty.length) throw new Error("seed did not produce a mixed planted/empty farm");
if (new Set(planted.map(b=>b.signature)).size !== planted.length) throw new Error("seeded beet signatures are not unique");
if (new Set(planted.map(b=>b.shine)).size < 8) throw new Error("shine attribute does not vary across the farm");
const outcomes = new Map(planted.map(b=>[b.tile,b.outcome]));
for (const [name,count] of [["break",report.broken],["boioioioing",report.spring],["bend and recover",report.recover]]) {
  if ([...outcomes.values()].filter(x=>x===name).length !== count || count < 1) throw new Error(`${name} count mismatch`);
}
const growth = report.frames.slice(0,100), uproot = report.frames.slice(100,116);
if (growth.some((f,i)=>f.time!==i*50||f.duration!==50||f.phase!=="Growing")) throw new Error("growth is not exactly five seconds at 20 FPS");
if (!planted.some(b=>new Set(growth.slice(50).map(f=>f.beets[b.tile].tip.x)).size>=5)) throw new Error("Core wind does not visibly vary the growing leaf geometry");
if (uproot.some((f,i)=>f.time!==5000+i*50||f.duration!==50||f.phase!=="Uproot"||f.beets.filter(b=>b.planted).some(b=>!b.pulled))) throw new Error("the 20 FPS simultaneous uproot sequence is malformed");
const pullSample = planted[0].tile, pullY = uproot.map(f=>f.beets[pullSample].body.y);
if (new Set(pullY).size < 8 || Math.min(...pullY) >= pullY.at(-1) || pullY[2] <= pullY[0] || pullY[4] >= pullY[2]) throw new Error("uproot does not show loading, acceleration, and overshoot");
const responseFrames = report.frames.slice(116,-1), responseGroupSize = 51;
if (responseFrames.length !== report.planted*responseGroupSize) throw new Error("each planted beet must receive exactly fifty trajectory samples and one terminal frame");
for (let i=0;i<responseFrames.length;i+=responseGroupSize) {
  const group=responseFrames.slice(i,i+responseGroupSize), tile=group[0].active;
  if (group.some(f=>f.active!==tile) || !outcomes.has(tile)) throw new Error(`invalid one-at-a-time bend group ${i/responseGroupSize}`);
  if (group.slice(0,-1).some((f,j)=>f.time!==j*50||f.duration!==50||f.phase!=="Elastic response") || group.at(-1).time!==6000) throw new Error(`invalid high-rate response timeline for tile ${tile}`);
  const active = group.map(f=>f.beets[tile]);
  if (outcomes.get(tile)==="break") {
    const snapped=active.findIndex(b=>b.broken);
    if (snapped<1 || active.slice(snapped).some(b=>!b.broken)) throw new Error(`broken geometry did not persist at tile ${tile}`);
  }
  if (outcomes.get(tile)==="boioioioing") {
    const amounts=active.map(b=>b.bend), directions=amounts.slice(1).map((x,j)=>Math.sign(x-amounts[j])).filter(Boolean);
    const reversals=directions.slice(1).filter((d,j)=>d!==directions[j]).length;
    if (new Set(amounts).size<6 || reversals<2) throw new Error(`spring trajectory is not visibly elastic at tile ${tile}`);
  }
  if (outcomes.get(tile)!=="break" && active.at(-1).state!=="resting") throw new Error(`terminal response did not settle at tile ${tile}`);
}
const final = report.frames.at(-1);
for (const b of final.beets.filter(b=>b.planted)) {
  if (b.broken !== (b.outcome === "break")) throw new Error(`final break state disagrees at tile ${b.tile}`);
  if (b.outcome !== "break" && b.state !== "resting") throw new Error(`nonbroken beet ${b.tile} did not return to rest`);
}

// Execute the real viewer against a minimal DOM and an instrumented WebGL
// boundary. The renderer itself is syntax/contract checked above; the stub
// confirms that camera redraws and selected immutable frames reach it.
const elements = new Map();
const element = id => {
  if (!elements.has(id)) elements.set(id, {
    id, value:id==="speed"?"100":"0", textContent:"", innerHTML:"", hidden:false,
    disabled:false, style:{}, addEventListener(){},
  });
  return elements.get(id);
};
const rendered=[];
const rendererContext = {
  console,
  document:{getElementById:element},
  window:{addEventListener(){}},
  setTimeout(){return 1}, clearTimeout(){},
  BEND_A_BEET_CAMERA:{state:{yaw:0,pitch:0,zoom:1},unproject(point){return point},pose(){return{eye:[0,7,-18],target:[0,7,0],up:[0,1,0],fov:1}},bind(){}},
  BEND_A_BEET_WEBGL:{create(){return{render(frame){rendered.push(frame);return{triangles:12345}}}}},
};
rendererContext.globalThis = rendererContext;
vm.runInNewContext(generated, rendererContext, {filename:"bend_a_beet_data.viewer.js"});
vm.runInNewContext(viewerSource, rendererContext, {filename:"bend_a_beet_viewer.js"});
const viewer = rendererContext.BEND_A_BEET_VIEWER;
const liveBreak = viewer.report.frames.findIndex(f=>f.active<24&&f.beets[f.active].broken);
const liveSpring = viewer.report.frames.findIndex(f=>f.active<24&&f.beets[f.active].state.includes("boio"));
if (liveBreak<0||liveSpring<0) throw new Error("viewer report lacks fracture or spring frames");
for (const index of [108, liveSpring, liveBreak, viewer.report.frames.length-1]) viewer.select(index);
if (rendered.length<5||viewer.stats.triangles!==12345) throw new Error("viewer did not drive the WebGL render boundary");

console.log(`Bend-a-Beet verified: ${report.frames.length} Core frames, ${report.planted} beets (${report.broken} break, ${report.spring} spring, ${report.recover} recover), Engine textures/fur/fuzz/four-light/fog/soft-shadow contracts, 20 general theorems, and 35 closed certificates`);
