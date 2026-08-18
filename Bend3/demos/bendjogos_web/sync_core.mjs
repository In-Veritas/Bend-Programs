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
  {
    name: "Bend-a-Beet",
    slug: "bend-a-beet",
    source: "bend_a_beet",
    data: "bend_a_beet_data.js",
    extras: ["bend_a_beet_camera.js"],
    inline: ["bend_a_beet_webgl.js", "bend_a_beet_viewer.js"],
  },
];

fs.mkdirSync(core, { recursive: true });
for (const pkg of packages) {
  const files = [
    { source: "index.html", target: `${pkg.slug}.html` },
    { source: pkg.data, target: pkg.data },
    ...(pkg.extras ?? []).map(file => ({ source: file, target: file })),
  ];
  const source = demoRoots
    .map(root => path.join(root, pkg.source ?? pkg.slug))
    .find(candidate => files.every(file => fs.existsSync(path.join(candidate, file.source))) && (pkg.inline ?? []).every(file => fs.existsSync(path.join(candidate, file))));
  const targets = files.map(file => path.join(core, file.target));
  if (source) {
    files.forEach((file, index) => fs.copyFileSync(path.join(source, file.source), targets[index]));
    if ((pkg.inline ?? []).length) {
      const page = targets[0];
      let html = fs.readFileSync(page, "utf8");
      for (const file of pkg.inline) {
        html = html.replace(`<script src="${file}"></script>`, `<script>\n${fs.readFileSync(path.join(source, file), "utf8")}\n</script>`);
      }
      fs.writeFileSync(page, html);
    }
    console.log(`Core ${pkg.name} assets synchronized from ${source}`);
  } else if (targets.every(target => fs.existsSync(target))) {
    console.log(`Core ${pkg.name} source not found; using checked-in synchronized assets.`);
  } else {
    throw new Error(`Core ${pkg.name} assets are missing; build Bend2 Core/demos/${pkg.source ?? pkg.slug} first.`);
  }
}
