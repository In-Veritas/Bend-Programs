import fs from "node:fs";
import vm from "node:vm";

const html = fs.readFileSync(new URL("./index.html", import.meta.url), "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match => match[1]);
if (scripts.length !== 1) throw new Error(`expected one inline client script, found ${scripts.length}`);
new vm.Script(scripts[0], {filename: "farmhands-client.js"});
for (const marker of ["FARMHANDS_CLIENT", "canSteal", "canHarvest", "remainingMs", "localStorage"]) {
  if (!html.includes(marker)) throw new Error(`missing client contract marker: ${marker}`);
}
console.log("Farmhands client: syntax and snapshot contract verified");
