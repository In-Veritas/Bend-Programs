// Regression test for the Core Poker artifact (latest Bend; run with `bun test.mjs`).
// Needs `bend` and `bun` on PATH. It re-checks the sources, runs the erased
// proof entry through generated JS and a native binary, and validates the
// published poker_data.js report.
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const here = dirname(fileURLToPath(import.meta.url));
const source = readFileSync(join(here, "poker.bend"), "utf8");
const proofs = readFileSync(join(here, "poker_proofs.bend"), "utf8");
const generated = readFileSync(join(here, "poker_data.js"), "utf8");
const html = readFileSync(join(here, "index.html"), "utf8");

for (const [name, text] of [["poker.bend", source], ["poker_proofs.bend", proofs]]) {
  if (/#\[halts\]|@unsafe|\?TODO/.test(text)) throw new Error(`${name} must not opt out of termination checking or leave open goals`);
}
if (!html.includes('src="poker_data.js"')) throw new Error("viewer does not use the relative Core artifact");
if (!html.includes('option value="texas"') || !html.includes('option value="omaha"')) throw new Error("viewer variant toggle missing");
if (!html.includes('id="proof-title"')) throw new Error("viewer verification audit missing");
if (!source.includes("./poker_proofs.bend")) throw new Error("Poker does not import its semantic conservation proof");
for (const theorem of ["texas_cards_length_theorem", "omaha_cards_length_theorem", "complete_rounds_balanced_theorem"]) {
  if (!new RegExp(`^law ${theorem}:`, "m").test(source)) throw new Error(`missing general theorem ${theorem}`);
}
for (const theorem of ["history_payload_conservation_theorem", "history_chip_count_conservation_theorem", "history_chip_value_conservation_theorem"]) {
  if (!new RegExp(`^law ${theorem}:`, "m").test(proofs)) throw new Error(`missing semantic theorem ${theorem}`);
}
if (!source.includes("closed certificates") || !source.includes("not probability theorems")) throw new Error("finite certificates are not scoped honestly");

const run = (cmd, args) => spawnSync(cmd, args, { cwd: here, encoding: "utf8" });
for (const file of ["poker.bend", "poker_proofs.bend", "poker_proofs_test.bend"]) {
  const check = run("bend", [file, "--check-only"]);
  if (check.status !== 0 || !check.stdout.includes("ALL PROOFS CHECK")) throw new Error(`${file} does not check:\n${check.stdout}${check.stderr}`);
}
const tmp = mkdtempSync(join(tmpdir(), "bend-poker-test-"));
try {
  const proofJs = join(tmp, "poker_proofs_test.js"), proofBin = join(tmp, "poker_proofs_test");
  for (const out of [proofJs, proofBin]) {
    const build = run("bend", ["poker_proofs_test.bend", "-o", out]);
    if (build.status !== 0) throw new Error(`proof entry did not build ${out}:\n${build.stdout}${build.stderr}`);
  }
  const js = run("bun", [proofJs]);
  if (js.status !== 0 || js.stdout.trim() !== "True{}") throw new Error(`proof JS failed:\n${js.stdout}${js.stderr}`);
  const native = run(proofBin, []);
  if (native.status !== 0 || native.stdout.trim() !== "True{}") throw new Error(`proof native run failed:\n${native.stdout}${native.stderr}`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}

for (const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) {
  if (match[1].trim()) new Function(match[1]);
}
const context = { globalThis: {} };
vm.runInNewContext(generated, context, { filename: "poker_data.js" });
const report = context.globalThis.BEND2_POKER_DATA;
if (!report || report.$ !== "PokerReport") throw new Error("missing PokerReport");
const list = xs => { const out=[]; while(xs && xs.$ === "Con"){out.push(xs.head);xs=xs.tail;} return out; };
const results=[];
for (const [name,timeline,min] of [["Texas",report.texas,20],["Omaha",report.omaha,24]]) {
  if (timeline.$ !== "Timeline") throw new Error(`${name}: missing timeline`);
  const steps=list(timeline.steps);
  if (steps.length<min) throw new Error(`${name}: incomplete timeline (${steps.length})`);
  for (const step of steps) {
    const players=list(step.players);
    if(players.length!==4) throw new Error(`${name}: expected four players`);
    const total=players.reduce((sum,p)=>sum+p.odds.win,0);
    if(total!==100) throw new Error(`${name}: win equity totals ${total}`);
    for (const player of players) {
      const o=player.odds;
      const categoryTotal=o.high+o.pair+o.two_pair+o.trips+o.straight+o.flush+o.full_house+o.quads;
      if(categoryTotal!==100) throw new Error(`${name}: seat ${player.seat} category odds total ${categoryTotal}`);
      if(!player.active && o.win!==0) throw new Error(`${name}: folded seat ${player.seat} retains win equity`);
    }
    if(list(step.board).some(card=>card<0||card>=52)) throw new Error(`${name}: invalid card`);
  }
  const showdown=steps.at(-1);
  if(showdown.action!=="win") throw new Error(`${name}: no showdown winner`);
  if(timeline.winner!==3||showdown.actor!==3) throw new Error(`${name}: River Rook should win`);
  for(const player of list(showdown.players)) {
    const expected=player.seat===timeline.winner?100:0;
    if(player.odds.win!==expected) throw new Error(`${name}: showdown equity does not match declared winner`);
  }
  for(const step of steps){const sum=list(step.players).reduce((n,p)=>n+p.stack,0)+step.pot;if(sum!==4000)throw new Error(`${name}: chips not conserved (${sum})`);}
  results.push(`${timeline.variant} seed ${timeline.seed}: ${steps.length} steps, River Rook wins ${showdown.amount}`);
}
const verification=report.verification;
if(!verification||verification.$!=="PokerVerificationAudit") throw new Error("missing machine-checked verification audit");
if(verification.certified_cases!==78||verification.general_theorems!==6) throw new Error(`verification audit expected 6 theorems and 78 certificates, got ${verification.general_theorems} and ${verification.certified_cases}`);
if(!verification.fairness.includes("runout")||!verification.unrigged.includes("each seat")||!verification.odds.includes("category/win")) throw new Error("verification audit claims are incomplete");
if(!verification.limitation.includes("not probability theorems")) throw new Error("probability certificate scope disclaimer missing");
for (const line of results) console.log(line);
console.log("Poker artifact: timelines, 3 semantic conservation theorems, 3 structural lemmas, and 78 closed certificates verified");
