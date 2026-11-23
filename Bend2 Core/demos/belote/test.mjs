import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

// Needs `bend` (latest bendlang/bend) and clang on PATH; run with bun or node.
const packageDirectory=dirname(fileURLToPath(import.meta.url));

const generated=readFileSync(new URL("./belote_data.js",import.meta.url),"utf8");
const html=readFileSync(new URL("./index.html",import.meta.url),"utf8");
const source=readFileSync(new URL("./belote.bend",import.meta.url),"utf8");
const proofs=readFileSync(new URL("./belote_proofs.bend",import.meta.url),"utf8");
for(const text of [source,proofs])if(/#\[halts\]|@unsafe|\?TODO/.test(text))throw new Error("Belote must not opt out of termination checking or leave proofs open");
if(!source.includes("./belote_proofs.bend"))throw new Error("Belote does not import its semantic conservation proof");
if(!source.includes("law play_steps_from_indices_length_theorem"))throw new Error("missing general list theorem");
for(const theorem of ["history_payload_conservation_theorem","history_card_count_conservation_theorem","history_card_value_conservation_theorem","reassign_payload_preservation_theorem"]){if(!proofs.includes(`law ${theorem}`))throw new Error(`missing semantic theorem ${theorem}`);}
for(const certificate of ["deck_cards_certificate","hand_size_certificate","play_owned_certificate","play_legal_certificate","trick_points_certificate","trick_winner_certificate","score_total_certificate","report_length_certificate","rules_valid_certificate"]){if(!source.includes(`law ${certificate}:`))throw new Error(`missing certificate family ${certificate}`);}
if(!source.includes("not general proofs")||!source.includes("do not generalize to every deal"))throw new Error("finite certificates are not scoped honestly");
const tmp=process.env.TMPDIR||"/tmp", proofEntry=join(packageDirectory,"belote_proofs_test.bend");
const run=(cmd,args)=>spawnSync(cmd,args,{cwd:packageDirectory,encoding:"utf8"});
for(const file of [proofEntry,join(packageDirectory,"belote_proofs.bend")]){const r=run("bend",[file,"--check-only"]);if(r.status!==0||!r.stdout.includes("ALL PROOFS CHECK"))throw new Error(`${file} does not check:\n${r.stdout}${r.stderr}`);}
const proofJs=join(tmp,"bend-belote-proofs.js"),proofBin=join(tmp,"bend-belote-proofs");
for(const output of [proofJs,proofBin]){const r=run("bend",[proofEntry,"-o",output]);if(r.status!==0)throw new Error(`Belote proof entry did not build ${output}:\n${r.stdout}${r.stderr}`);}
const proofJsRun=run(process.execPath,[proofJs]);if(proofJsRun.status!==0||proofJsRun.stdout.trim()!=="True{}")throw new Error(`Belote proof JS failed:\n${proofJsRun.stdout}${proofJsRun.stderr}`);
const proofNativeRun=run(proofBin,[]);if(proofNativeRun.status!==0||proofNativeRun.stdout.trim()!=="True{}")throw new Error(`Belote proof native run failed:\n${proofNativeRun.stdout}${proofNativeRun.stderr}`);
if(!html.includes('src="belote_data.js"')||!html.includes("no browser clock, DOM input, or host randomness")||!html.includes('id="proof-title"'))throw new Error("relative artifact, boundary note or audit panel missing");
for(const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)){if(match[1].trim())new Function(match[1]);}
const context={globalThis:{}};vm.runInNewContext(generated,context,{filename:"belote_data.js"});
const report=context.globalThis.BEND2_BELOTE_DATA;
if(!report||report.$!=="BeloteReport"||report.valid!==true)throw new Error("missing or invalid BeloteReport");
const audit=report.verification;
if(!audit||audit.$!=="BeloteVerificationAudit"||audit.certified_cases!==119||audit.general_theorems!==4||!audit.legality.includes("follow-suit"))throw new Error("missing or invalid verification audit");
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
console.log("Belote artifact: deal, bidding, 32 legal plays, 8 tricks, 47-115 score, 3 semantic conservation theorems, 1 structural lemma and 119 closed certificates verified");
