import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const core = path.join(here, "core");
const demoRoots = [
  path.resolve(here, "../../../Bend-Programs/Bend2 Core/demos"),
  path.resolve(here, "../../../Bend2 Core/demos"),
];
const packages = [
  { name: "Poker", slug: "poker", data: "poker_data.js" },
  { name: "Belote", slug: "belote", data: "belote_data.js" },
];

fs.mkdirSync(core, { recursive: true });
for (const pkg of packages) {
  const source = demoRoots
    .map(root => path.join(root, pkg.slug))
    .find(candidate =>
      fs.existsSync(path.join(candidate, "index.html")) &&
      fs.existsSync(path.join(candidate, pkg.data))
    );
  const targets = [path.join(core, `${pkg.slug}.html`), path.join(core, pkg.data)];
  if (source) {
    fs.copyFileSync(path.join(source, "index.html"), targets[0]);
    fs.copyFileSync(path.join(source, pkg.data), targets[1]);
    console.log(`Core ${pkg.name} assets synchronized from ${source}`);
  } else if (targets.every(target => fs.existsSync(target))) {
    console.log(`Core ${pkg.name} source not found; using checked-in synchronized assets.`);
  } else {
    throw new Error(`Core ${pkg.name} assets are missing; build Bend2 Core/demos/${pkg.slug} first.`);
  }
}
