import { readFileSync } from "node:fs";
import vm from "node:vm";

const generated=readFileSync(new URL("./belote_data.js",import.meta.url),"utf8");
const html=readFileSync(new URL("./index.html",import.meta.url),"utf8");
const source=readFileSync(new URL("./belote.bend",import.meta.url),"utf8");
if(/#\[halts\]|@unsafe/.test(source))throw new Error("Belote must not opt out of termination checking");
if(!html.includes('src="belote_data.js"')||!html.includes("uses no IO, clock, or host randomness"))throw new Error("relative artifact or Core limitation note missing");
for(const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)){if(match[1].trim())new Function(match[1]);}
const context={globalThis:{}};vm.runInNewContext(generated,context,{filename:"belote_data.js"});
const report=context.globalThis.BEND2_BELOTE_DATA;
if(!report||report.$!=="BeloteReport"||report.valid!==true)throw new Error("missing or invalid BeloteReport");
const list=xs=>{const out=[];while(xs&&xs.$==="Con"){out.push(xs.head);xs=xs.tail;}return out;};
const steps=list(report.steps), initial=list(steps[0].players), all=initial.flatMap(p=>list(p.hand));
if(steps.length!==36)throw new Error(`expected 36 observer steps, got ${steps.length}`);
if(initial.length!==4||initial.some(p=>list(p.hand).length!==8)||new Set(all).size!==32)throw new Error("deal is not four disjoint eight-card hands");
const plays=steps.filter(s=>s.action==="lead"||s.action==="play"||s.action==="complete trick");if(plays.length!==32)throw new Error("hand does not contain 32 plays");
const hands=initial.map(p=>list(p.hand)), trump=report.trump, trumpStrength=[0,1,6,7,2,3,4,5], plainStrength=[0,1,2,3,4,5,6,7];
const suit=c=>Math.floor(c/8), strength=c=>(suit(c)===trump?trumpStrength:plainStrength)[c%8];
const winner=trick=>{let w=0;for(let i=1;i<trick.length;i++){const a=trick[i].card,b=trick[w].card;if((suit(a)===trump&&suit(b)!==trump)||(suit(a)===suit(b)&&strength(a)>strength(b)))w=i;}return trick[w].seat;};
const legal=(hand,trick,seat)=>{if(!trick.length)return hand;const lead=suit(trick[0].card),same=hand.filter(c=>suit(c)===lead);if(same.length){if(lead!==trump)return same;const top=Math.max(...trick.filter(x=>suit(x.card)===trump).map(x=>strength(x.card))),over=same.filter(c=>strength(c)>top);return over.length?over:same;}if(winner(trick)===(seat+2)%4)return hand;const trumps=hand.filter(c=>suit(c)===trump);if(!trumps.length)return hand;const top=Math.max(-1,...trick.filter(x=>suit(x.card)===trump).map(x=>strength(x.card))),over=trumps.filter(c=>strength(c)>top);return over.length?over:trumps;};
const value=c=>suit(c)===trump?[0,0,14,20,3,4,10,11][c%8]:[0,0,0,2,3,4,10,11][c%8];
let leader=0,trick=[],points=[0,0],tricks=0;for(let i=0;i<plays.length;i++){const s=plays[i],seat=s.actor,card=s.card,expected=(leader+trick.length)%4;if(seat!==expected)throw new Error(`play ${i}: actor ${seat}, expected ${expected}`);if(!legal(hands[seat],trick,seat).includes(card))throw new Error(`play ${i}: illegal card ${card}`);hands[seat].splice(hands[seat].indexOf(card),1);trick.push({seat,card});if(list(s.table).length!==trick.length)throw new Error(`play ${i}: Bend trick table disagrees`);if(trick.length===4){const w=winner(trick),p=trick.reduce((n,x)=>n+value(x.card),0)+(i===31?10:0);points[w%2]+=p;leader=w;trick=[];tricks++;if(s.north_south!==points[0]||s.east_west!==points[1]||s.trick!==tricks)throw new Error(`trick ${tricks}: Bend score ${s.north_south}-${s.east_west}, expected ${points}`);}}
if(tricks!==8)throw new Error(`expected 8 tricks, got ${tricks}`);
if(points[0]!==47||points[1]!==115||report.card_points_ns!==47||report.card_points_ew!==115)throw new Error(`score mismatch: ${points}`);
if(hands.some(h=>h.length))throw new Error("cards remain after eight tricks");
if(!plays[8].note.includes("must cut")||!plays[10].note.includes("must overtrump"))throw new Error("cut/overtrump observer notes missing");
console.log("Belote artifact: deal, bidding, 32 legal plays, 8 tricks and 47-115 score verified");
