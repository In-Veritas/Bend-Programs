import { readFileSync } from "node:fs";
import vm from "node:vm";

const source = readFileSync(new URL("./poker.bend", import.meta.url), "utf8");
if (/#\[halts\]|@unsafe/.test(source)) throw new Error("poker.bend must not opt out of termination checking");
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
    if(list(step.board).some(card=>card<0||card>=52)) throw new Error(`${name}: invalid card`);
  }
  if(steps.at(-1).action!=="win") throw new Error(`${name}: no showdown winner`);
  if(timeline.winner!==3||steps.at(-1).actor!==3) throw new Error(`${name}: River Rook should win`);
  for(const step of steps){const sum=list(step.players).reduce((n,p)=>n+p.stack,0)+step.pot;if(sum!==4000)throw new Error(`${name}: chips not conserved (${sum})`);}
  results.push(`${timeline.variant} seed ${timeline.seed}: ${steps.length} steps, River Rook wins ${steps.at(-1).amount}`);
}
for (const line of results) console.log(line);
console.log("Poker artifact: Texas and Omaha timelines verified");
