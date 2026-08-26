import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const packageDirectory = dirname(fileURLToPath(import.meta.url));
const core = resolve(process.env.BEND2_CORE || join(packageDirectory, "../../../../bend2-core"));
const revision = spawnSync("git", ["rev-parse", "HEAD"], { cwd: core, encoding: "utf8" });
if (revision.status !== 0 || !revision.stdout.trim().startsWith("c5d69a1")) {
  throw new Error(`Poker targets Bend c5d69a1, found ${revision.stdout.trim() || revision.stderr.trim()}`);
}

const generated = readFileSync(new URL("./poker_data.js", import.meta.url), "utf8");
const html = readFileSync(new URL("./index.html", import.meta.url), "utf8");
const source = readFileSync(new URL("./poker.bend", import.meta.url), "utf8");
const proofs = readFileSync(new URL("./poker_proofs.bend", import.meta.url), "utf8");
if (!html.includes('src="poker_data.js"')) throw new Error("viewer does not use the relative Core artifact");
if (!html.includes('option value="texas"') || !html.includes('option value="omaha"')) throw new Error("viewer variant toggle missing");
if (!html.includes('id="proof-title"')) throw new Error("viewer verification audit missing");
if (source.includes("#[halts]") || proofs.includes("#[halts]")) throw new Error("Poker uses the removed #[halts] spelling");
if (!source.includes("./poker_proofs.bend")) throw new Error("Poker does not import its semantic conservation proof");
for (const theorem of ["texas_cards_length_theorem", "omaha_cards_length_theorem", "complete_rounds_balanced_theorem"]) {
  if (!source.includes(theorem)) throw new Error(`missing general Core theorem ${theorem}`);
}
for (const theorem of ["history_payload_conservation_theorem", "history_chip_count_conservation_theorem", "history_chip_value_conservation_theorem"]) {
  if (!proofs.includes(theorem)) throw new Error(`missing semantic Core theorem ${theorem}`);
}
if (!source.includes("closed certificates") || !source.includes("not probability theorems")) throw new Error("finite certificates are not scoped honestly");
const proofJs = join(process.env.TMPDIR || "/tmp", "bend2-core-poker-proofs.js");
const proofC = join(process.env.TMPDIR || "/tmp", "bend2-core-poker-proofs.c");
const proofBin = join(process.env.TMPDIR || "/tmp", "bend2-core-poker-proofs");
for (const output of [proofJs, proofC]) {
  const compile = spawnSync("bun", [join(core, "bend2/comp.ts"), join(packageDirectory, "poker_proofs_test.bend"), "--to", output], { cwd:core, encoding:"utf8" });
  if (compile.status !== 0) throw new Error(`Poker proof entry did not emit ${output}:\n${compile.stdout}${compile.stderr}`);
}
const proofJsRun = spawnSync("bun", [proofJs], { cwd:core, encoding:"utf8" });
if (proofJsRun.status !== 0 || proofJsRun.stdout.trim() !== "True{}") throw new Error(`Poker proof JS failed:\n${proofJsRun.stdout}${proofJsRun.stderr}`);
const proofNativeBuild = spawnSync("clang", ["-O2", proofC, "-o", proofBin], { cwd:core, encoding:"utf8" });
if (proofNativeBuild.status !== 0) throw new Error(`Poker proof C failed to build:\n${proofNativeBuild.stdout}${proofNativeBuild.stderr}`);
const proofNativeRun = spawnSync(proofBin, ["--parallel", "off", "--gpu", "off"], { cwd:core, encoding:"utf8" });
if (proofNativeRun.status !== 0 || !/^True\{\}(?:\n|$)/.test(proofNativeRun.stdout)) throw new Error(`Poker proof native run failed:\n${proofNativeRun.stdout}${proofNativeRun.stderr}`);
for (const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) {
  if (match[1].trim()) new Function(match[1]);
}
const context = { globalThis: {} };
vm.runInNewContext(generated, context, { filename: "poker_data.js" });
const report = context.globalThis.BEND2_POKER_DATA;
if (!report || report.$ !== "PokerReport") throw new Error("missing PokerReport");
const list = xs => { const out=[]; while(xs && xs.$ === "Con"){out.push(xs.$0);xs=xs.$1;} return out; };
for (const [name,timeline,min] of [["Texas",report.$0,20],["Omaha",report.$1,24]]) {
  if (timeline.$ !== "Timeline") throw new Error(`${name}: missing timeline`);
  const steps=list(timeline.$4);
  if (steps.length<min) throw new Error(`${name}: incomplete timeline (${steps.length})`);
  for (const step of steps) {
    const players=list(step.$7);
    if(players.length!==4) throw new Error(`${name}: expected four players`);
    const total=players.reduce((sum,p)=>sum+p.$7.$0,0);
    if(total!==100) throw new Error(`${name}: win equity totals ${total}`);
    for (const player of players) {
      const categories=Array.from({length:8},(_,i)=>player.$7[`$${i+1}`]);
      const categoryTotal=categories.reduce((sum,value)=>sum+value,0);
      if(categoryTotal!==100) throw new Error(`${name}: seat ${player.$0} category odds total ${categoryTotal}`);
      if(!player.$3 && player.$7.$0!==0) throw new Error(`${name}: folded seat ${player.$0} retains win equity`);
    }
    if(list(step.$6).some(card=>card<0||card>=52)) throw new Error(`${name}: invalid card`);
  }
  const showdown=steps.at(-1);
  if(showdown.$3!=="win") throw new Error(`${name}: no showdown winner`);
  for(const player of list(showdown.$7)) {
    const expected=player.$0===timeline.$3?100:0;
    if(player.$7.$0!==expected) throw new Error(`${name}: showdown equity does not match declared winner`);
  }
}
const verification=report.$2;
if(!verification||verification.$!=="PokerVerificationAudit") throw new Error("missing machine-checked verification audit");
if(verification.$6!==78||verification.$7!==6) throw new Error(`verification audit expected 6 theorems and 78 certificates, got ${verification.$7} and ${verification.$6}`);
if(!verification.$2.includes("runout")||!verification.$3.includes("each seat")||!verification.$4.includes("category/win")) throw new Error("verification audit claims are incomplete");
if(!verification.$5.includes("not probability theorems")) throw new Error("probability certificate scope disclaimer missing");
console.log("Bend2 Core Poker artifact: timelines, 3 semantic conservation theorems, 3 structural lemmas, and 78 closed certificates verified");
