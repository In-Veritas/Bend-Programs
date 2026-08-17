import { readFileSync } from "node:fs";
import vm from "node:vm";

const generated = readFileSync(new URL("./poker_data.js", import.meta.url), "utf8");
const html = readFileSync(new URL("./index.html", import.meta.url), "utf8");
if (!html.includes('src="poker_data.js"')) throw new Error("viewer does not use the relative Core artifact");
if (!html.includes('option value="texas"') || !html.includes('option value="omaha"')) throw new Error("viewer variant toggle missing");
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
    if(list(step.$6).some(card=>card<0||card>=52)) throw new Error(`${name}: invalid card`);
  }
  if(steps.at(-1).$3!=="win") throw new Error(`${name}: no showdown winner`);
}
console.log("Bend2 Core Poker artifact: Texas and Omaha timelines verified");
