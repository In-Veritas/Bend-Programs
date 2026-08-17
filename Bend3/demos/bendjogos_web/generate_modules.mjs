import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Bend3 imports now merge declarations into one global book; `as Alias` is
// tooling metadata rather than a language namespace. BendJogos combines thirteen
// independently useful demos, so generate hub-private dotted declarations while
// keeping each standalone source unchanged and independently compilable.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outDir = path.join(root, "bendjogos_web", "modules");
const modules = [
  ["Tic", "tictactoe_web/web_tictactoe.bend"],
  ["Snake", "slither_web/web_slither.bend"],
  ["Cells", "agar_web/web_agar.bend"],
  ["Mine", "minecraft_web/web_minecraft.bend"],
  ["Cube", "cubeworld2_web/web_cubeworld2.bend"],
  ["Poker", "poker_web/web_poker.bend"],
  ["Belote", "belote_web/web_belote.bend"],
  ["Corvid", "club_corvid_web/web_club_corvid.bend"],
  ["Duck", "duck_hunt_web/web_duck_hunt.bend"],
  ["Obf", "bend_obfuscator_web/web_obfuscator.bend"],
  ["Social", "bendjogos_web/social.bend"],
  ["Bar", "bar_bench_web/web_bar.bend"],
  ["Elements", "elements_web/web_elements.bend"],
];

function codeEnd(line) {
  let quote = "";
  let escaped = false;
  for (let index = 0; index < line.length; index++) {
    const char = line[index];
    if (quote !== "") {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === quote) quote = "";
    } else if (char === '"' || char === "'") quote = char;
    else if (char === "#") return index;
  }
  return line.length;
}

function declarations(lines) {
  const types = new Set();
  const defs = new Set();
  const constructorLines = new Set();
  let inType = false;
  for (let index = 0; index < lines.length; index++) {
    const type = lines[index].match(/^type\s+([A-Za-z_][A-Za-z0-9_]*)/);
    const def = lines[index].match(/^def\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s*\(/);
    if (type) {
      types.add(type[1]);
      inType = true;
    } else if (def) {
      defs.add(def[1]);
      inType = false;
    } else if (/^[^ #\n]/.test(lines[index])) {
      inType = false;
    }
    if (inType && /^  [A-Za-z_][A-Za-z0-9_]*\{/.test(lines[index])) {
      constructorLines.add(index);
    }
  }
  const longestFirst = (a, b) => b.length - a.length;
  return {
    types: [...types].sort(longestFirst),
    defs: [...defs].sort(longestFirst),
    constructorLines,
  };
}

function replaceType(code, name, prefix) {
  const expression = new RegExp(`(?<![A-Za-z0-9_.])${name}(?![A-Za-z0-9_])`, "g");
  return code.replace(expression, `${prefix}.${name}`);
}

function transform(prefix, relative) {
  const source = fs.readFileSync(path.join(root, relative), "utf8");
  const lines = source.split("\n");
  const declared = declarations(lines);
  // The marker prevents a prefix such as `Snake` from being transformed again
  // when the source itself also declares a type named `Snake`.
  const marker = "__BENDJOGOS_NAMESPACE__";
  const output = lines.map((line, index) => {
    if (line === "import ../../bend-base/Base") return "import ../../../bend-base/Base";
    if (line === "import ../../bend-base/IO/TCP") return "import ../../../bend-base/IO/TCP";
    if (line === "import ../../bend-base/IO/HTTP") return "import ../../../bend-base/IO/HTTP";
    if (line === "import ../../bend-base/JSON") return "import ../../../bend-base/JSON";
    if (line === "import ../Compat") return "import ../../Compat";
    if (line.startsWith("import ../Clock")) return "import ../../Clock";

    const end = codeEnd(line);
    let code = line.slice(0, end);
    const constructor = declared.constructorLines.has(index)
      ? code.match(/^(  [A-Za-z_][A-Za-z0-9_]*)(\{.*)$/)
      : null;
    let head = "";
    if (constructor) {
      // A constructor's short name inside a type declaration remains short.
      head = constructor[1];
      code = constructor[2];
    }
    for (const name of declared.types) code = replaceType(code, name, marker);
    for (const name of declared.defs) {
      code = code.replace(
        new RegExp(`(?<![A-Za-z0-9_.])${name}(?=\\s*\\()`, "g"),
        `${marker}.${name}`,
      );
      // HTTP.Router stores a route function as a bare value.
      code = code.replace(new RegExp(`(?<=\\{)${name}(?=\\s*,)`, "g"), `${marker}.${name}`);
    }
    return head + code + line.slice(end);
  });
  output.splice(
    0,
    0,
    `# Generated hub-private namespace from ../${relative}.`,
    "# Regenerate after changing the standalone source.",
    "",
  );
  return output.join("\n").replaceAll(`${marker}.`, `${prefix}.`);
}

fs.mkdirSync(outDir, { recursive: true });
for (const [prefix, relative] of modules) {
  fs.writeFileSync(path.join(outDir, `${prefix}.bend`), transform(prefix, relative));
}
