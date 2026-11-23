// Inline the chunks of a `bend web/index.html -o <dir>` bundle into one HTML file.
// usage: bun inline.mjs <bundle-dir> <out.html>
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [dir, out] = process.argv.slice(2);
let html = readFileSync(join(dir, "index.html"), "utf8");
html = html.replace(/<script type="module"[^>]*src="\.\/([^"]+)"[^>]*><\/script>/g, (_, f) =>
  "<script type=\"module\">" + readFileSync(join(dir, f), "utf8").replace(/<\/script/gi, "<\\/script") + "</script>");
writeFileSync(out, html);
console.log("wrote " + out + " (" + (html.length / 1024).toFixed(1) + "kb)");
