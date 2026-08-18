import { readFileSync } from "node:fs";
import vm from "node:vm";

const generated = readFileSync(new URL("./poker_data.js", import.meta.url), "utf8");
const html = readFileSync(new URL("./index.html", import.meta.url), "utf8");
const source = readFileSync(new URL("./poker.bend", import.meta.url), "utf8");
if (!html.includes('src="poker_data.js"')) throw new Error("viewer does not use the relative Core artifact");
if (!html.includes('option value="texas"') || !html.includes('option value="omaha"')) throw new Error("viewer variant toggle missing");
if (!html.includes("Machine-checked proof audit") && !html.includes('id="proof-title"')) throw new Error("viewer proof audit missing");
if (source.includes("#[halts]")) throw new Error("Poker proof source must remain termination-checked");
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
const proofs=report.$2;
if(!proofs||proofs.$!=="ProofAudit") throw new Error("missing machine-checked proof audit");
if(proofs.$6!==78) throw new Error(`proof audit expected 78 cases, got ${proofs.$6}`);
if(!proofs.$2.includes("runout")||!proofs.$3.includes("Each seat")||!proofs.$4.includes("sums to 100")) throw new Error("proof audit claims are incomplete");
if(!proofs.$5.includes("not a claim")) throw new Error("probability proof scope disclaimer missing");
console.log("Bend2 Core Poker artifact: timelines and 78 proof cases verified");
