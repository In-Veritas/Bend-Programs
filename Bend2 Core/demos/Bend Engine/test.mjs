#!/usr/bin/env bun

import { spawnSync } from "node:child_process";
import { readFileSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const here = dirname(fileURLToPath(import.meta.url));
const core = resolve(process.env.BEND2_CORE || join(here, "../../../../bend2-core"));
const compiler = join(core, "bend2/comp.ts");
const entries = ["rendering_test.bend", "physics_test.bend", "ai_test.bend", "fluids_test.bend"];

function run(command, args, cwd = here) {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(
      `${command} ${args.join(" ")} failed\n${result.stdout}${result.stderr}`,
    );
  }
  return result.stdout.trim();
}

const revision = run("git", ["rev-parse", "HEAD"], core);
if (!revision.startsWith("c5d69a1")) {
  throw new Error(`Bend Engine targets Bend c5d69a1, found ${revision}`);
}

const webglSource = readFileSync(join(here, "bend_engine_webgl.js"), "utf8");
new Function(webglSource);
const rendererContext = { globalThis: {} };
vm.runInNewContext(webglSource, rendererContext, { filename: "bend_engine_webgl.js" });
const renderer = rendererContext.globalThis.BEND_ENGINE_WEBGL;
if (!renderer || typeof renderer.registerMesh !== "function" || typeof renderer.makeMesh !== "function") throw new Error("arbitrary indexed-mesh boundary is absent");
renderer.registerMesh("testTetrahedron", {
  positions: [0, 1, 0, -1, -1, 1, 1, -1, 1, 0, -1, -1],
  indices: [0, 1, 2, 0, 3, 1, 0, 2, 3, 1, 3, 2],
});
const meshStats = renderer.meshStats();
for (const name of ["capsule", "torus", "branch", "leaf", "wing", "fishBody", "whaleBody", "manta", "island", "arch", "crystal", "star"]) {
  if (!meshStats[name] || meshStats[name].triangles < 20) throw new Error(`complex procedural mesh ${name} is absent or degenerate`);
}
if (Object.keys(meshStats).length < 30 || meshStats.testTetrahedron.triangles !== 4 || meshStats.fishBody.vertices < 900 || meshStats.whaleBody.triangles < 2000) throw new Error("procedural/custom mesh statistics regressed");
for (const [name, model] of [["hero", renderer.hero()], ["bird", renderer.bird("furball")], ["fish", renderer.fish(8)], ["whale", renderer.whale()], ["tree", renderer.tree()]]) {
  if (!Array.isArray(model) || model.length < 5 || !model.some(part => !["box", "sphere", "cone", "cylinder"].includes(part.kind))) throw new Error(`${name} did not produce a complex assembly`);
}
for (const token of ["uNormalMatrix", "uWind", "uSubsurface", "registerMesh", "transparent", "sort((left, right)"]) if (!webglSource.includes(token)) throw new Error(`shared renderer misses ${token}`);

for (const name of readdirSync(here).filter((name) => name.endsWith(".bend"))) {
  const source = readFileSync(join(here, name), "utf8");
  if (/^\s*#\[halts\]/m.test(source)) {
    throw new Error(`${name} uses the removed #[halts] spelling`);
  }
}

for (const entry of entries) {
  const stem = `bend-engine-${process.pid}-${entry.slice(0, -5)}`;
  const js = join(tmpdir(), `${stem}.js`);
  const c = join(tmpdir(), `${stem}.c`);
  const executable = join(tmpdir(), stem);

  try {
    run("bun", [compiler, join(here, entry), "--to", js], core);
    const jsResult = run("bun", [js], core);
    if (jsResult !== "True{}") {
      throw new Error(`${entry} JavaScript backend returned ${JSON.stringify(jsResult)}`);
    }

    run("bun", [compiler, join(here, entry), "--to", c], core);
    run("clang", ["-O2", c, "-o", executable], core);
    const cResult = run(executable, ["--parallel", "off", "--gpu", "off"], core);
    if (!/^True\{\}(?:\n|$)/.test(cResult)) {
      throw new Error(`${entry} C backend returned ${JSON.stringify(cResult)}`);
    }
  } finally {
    for (const path of [js, c, executable]) rmSync(path, { force: true });
  }
}

console.log(
  `Bend Engine verified at ${revision.slice(0, 7)}: ${entries.length} focused entries passed generated JavaScript and native C`,
);
