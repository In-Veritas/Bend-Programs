// Build the browser visualization for the water_movement demo.
//
// The Bend program (main.bend) is PURE: it prints the simulation as JSON.
// This script does the IO: it runs the compiled program, saves the data to
// frames.json, and writes a standalone water.html that animates it in a
// browser (auto-looping, like a gif). All visualization lives here / in the
// HTML — nothing is inside the Bend program.
//
// Usage: bun build.mjs <compiled.js> <out.html> <out.json>

import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";

const TEMPLATE = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Water Movement</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; background: #050d14; color: #cfe8f5;
         font-family: system-ui, sans-serif; padding: 18px; }
  h1 { font-size: 20px; color: #7fdfff; margin: 0 0 4px; }
  .sub { font-size: 12.5px; color: #6f93a6; margin: 0 0 14px; }
  .grid { display: grid; gap: 16px; }
  .panel { background: #081722; border: 1px solid #14384c; border-radius: 10px;
           padding: 8px 10px 10px; }
  .panel h2 { font-size: 13px; font-weight: 600; color: #bfe0ef; margin: 0 0 6px; }
  canvas { display: block; border-radius: 6px; background: #06121b; }
  .bar { margin-top: 14px; font-size: 13px; color: #9fc7d8; display: flex;
         align-items: center; gap: 12px; flex-wrap: wrap; }
  input[type=range] { width: 220px; }
  button { background: #103047; color: #cfe8f5; border: 1px solid #1d5b75;
           border-radius: 6px; padding: 4px 10px; cursor: pointer; font-size: 13px; }
</style>
</head>
<body>
  <h1>Water Movement</h1>
  <div class="sub">Bend simulates (pure, no IO) → frames.json → this page renders &amp; loops it.</div>
  <div class="grid" id="grid"></div>
  <div class="bar">
    <button id="pause">⏸ pause</button>
    <span>speed</span>
    <input type="range" id="speed" min="20" max="240" value="170">
    <span id="info"></span>
  </div>
<script>
/*__DATA__*/
const W = DATA.w, H = DATA.h, CELL = 9;

const ramp = (t, stops) => {
  t = Math.max(0, Math.min(0.9999, t));
  const n = stops.length - 1, f = t * n, i = Math.floor(f), u = f - i;
  const a = stops[i], b = stops[i + 1];
  const m = (k) => (a[k] + (b[k] - a[k]) * u) | 0;
  return "rgb(" + m(0) + "," + m(1) + "," + m(2) + ")";
};
const HEIGHT = [[6,28,52],[24,96,158],[86,196,236],[226,250,255]];
const WATER  = [[10,44,78],[26,108,176],[150,225,255]];

function cellColor(kind, level) {
  if (kind === 3) {                      // particles: density (air is empty)
    if (level <= 0) return null;
    return ramp(level / 30, WATER);
  }
  return ramp(level / 40, HEIGHT);       // grids: height field
}

function drawRock(ctx, p) {
  if (!p.rk) return;
  const cx = (p.rx + 0.5) * CELL, cy = (p.ry + 0.5) * CELL, r = p.rr * CELL;
  ctx.fillStyle = "#5b6470";
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, 7); ctx.fill();
  ctx.lineWidth = 1.5; ctx.strokeStyle = "#2a2f37"; ctx.stroke();
  ctx.fillStyle = "#828c98";
  ctx.beginPath(); ctx.arc(cx - r * 0.3, cy - r * 0.3, r * 0.34, 0, 7); ctx.fill();
}

function drawFish(ctx, p) {
  if (!p.hf) return;
  const cx = (p.fx + 0.5) * CELL, cy = (p.fy + 0.5) * CELL;
  const r = CELL * 0.95, dir = p.fr ? 1 : -1;
  ctx.save(); ctx.translate(cx, cy); ctx.scale(dir, 1);
  ctx.fillStyle = "#ffcf4d";
  ctx.beginPath(); ctx.ellipse(0, 0, r, r * 0.55, 0, 0, 7); ctx.fill();
  ctx.beginPath(); ctx.moveTo(-r * 0.8, 0); ctx.lineTo(-r * 1.7, -r * 0.55);
  ctx.lineTo(-r * 1.7, r * 0.55); ctx.closePath(); ctx.fill();
  ctx.fillStyle = "#10222e";
  ctx.beginPath(); ctx.arc(r * 0.45, -r * 0.12, r * 0.13, 0, 7); ctx.fill();
  ctx.restore();
}

const canvases = [];
const grid = document.getElementById("grid");
grid.style.gridTemplateColumns = "repeat(" + (DATA.cols || 2) + ", max-content)";
DATA.meta.forEach((m) => {
  const panel = document.createElement("div"); panel.className = "panel";
  const h = document.createElement("h2"); h.textContent = m.title;
  const cv = document.createElement("canvas");
  cv.width = W * CELL; cv.height = H * CELL;
  panel.appendChild(h); panel.appendChild(cv); grid.appendChild(panel);
  canvases.push({ ctx: cv.getContext("2d"), kind: m.kind });
});

function drawFrame(fi) {
  const fr = DATA.frames[fi];
  canvases.forEach((c, pi) => {
    const p = fr.p[pi], g = p.g, ctx = c.ctx;
    ctx.fillStyle = "#06121b"; ctx.fillRect(0, 0, W * CELL, H * CELL);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const col = cellColor(c.kind, g[y * W + x]);
      if (col) { ctx.fillStyle = col; ctx.fillRect(x * CELL, y * CELL, CELL, CELL); }
    }
    drawRock(ctx, p);
    drawFish(ctx, p);
  });
}

let fi = 0, paused = false, delay = 90, last = 0;
const info = document.getElementById("info");
function loop(t) {
  if (!paused && t - last >= delay) {
    drawFrame(fi);
    info.textContent = "frame " + (fi + 1) + " / " + DATA.frames.length;
    fi = (fi + 1) % DATA.frames.length;
    last = t;
  }
  requestAnimationFrame(loop);
}
document.getElementById("pause").onclick = (e) => {
  paused = !paused; e.target.textContent = paused ? "▶ play" : "⏸ pause";
};
document.getElementById("speed").oninput = (e) => { delay = 260 - Number(e.target.value); };
drawFrame(0);
requestAnimationFrame(loop);
</script>
</body>
</html>
`;

const [js, outHtml, outJson] = process.argv.slice(2);
if (!js || !outHtml || !outJson) {
  console.error("usage: bun build.mjs <compiled.js> <out.html> <out.json>");
  process.exit(1);
}

const raw = execFileSync("bun", [js], { maxBuffer: 1 << 27 }).toString().trim();
const dataStr = JSON.parse(raw); // the runtime prints a JSON string literal
JSON.parse(dataStr); // validate it really is JSON
writeFileSync(outJson, dataStr);

const html = TEMPLATE.replace("/*__DATA__*/", "const DATA = " + dataStr + ";");
writeFileSync(outHtml, html);
console.log("wrote " + outJson + " (" + dataStr.length + " bytes) and " + outHtml);
