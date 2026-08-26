import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const packageDirectory=dirname(fileURLToPath(import.meta.url));
const core=resolve(process.env.BEND2_CORE||join(packageDirectory,"../../../../bend2-core"));
const revision=spawnSync("git",["rev-parse","HEAD"],{cwd:core,encoding:"utf8"});
if(revision.status!==0||!revision.stdout.trim().startsWith("c5d69a1"))throw new Error(`Belote targets Bend c5d69a1, found ${revision.stdout.trim()||revision.stderr.trim()}`);

const generated=readFileSync(new URL("./belote_data.js",import.meta.url),"utf8");
const html=readFileSync(new URL("./index.html",import.meta.url),"utf8");
const source=readFileSync(new URL("./belote.bend",import.meta.url),"utf8");
const proofs=readFileSync(new URL("./belote_proofs.bend",import.meta.url),"utf8");
if(source.includes("#[halts]")||proofs.includes("#[halts]"))throw new Error("Belote uses the removed #[halts] spelling");
if(!source.includes("./belote_proofs.bend"))throw new Error("Belote does not import its semantic conservation proof");
if(!source.includes("play_steps_from_indices_length_theorem_func"))throw new Error("missing general Core list theorem");
for(const theorem of ["history_payload_conservation_theorem","history_card_count_conservation_theorem","history_card_value_conservation_theorem"]){if(!proofs.includes(theorem))throw new Error(`missing semantic Core theorem ${theorem}`);}
for(const certificate of ["deck_cards_certificate_func","hand_size_certificate_func","play_owned_certificate_func","play_legal_certificate_func","trick_points_certificate_func","trick_winner_certificate_func"]){if(!source.includes(certificate))throw new Error(`missing Core certificate family ${certificate}`);}
if(!source.includes("not general proofs")||!source.includes("do not generalize to every deal"))throw new Error("finite certificates are not scoped honestly");
const proofJs=join(process.env.TMPDIR||"/tmp","bend2-core-belote-proofs.js"),proofC=join(process.env.TMPDIR||"/tmp","bend2-core-belote-proofs.c"),proofBin=join(process.env.TMPDIR||"/tmp","bend2-core-belote-proofs");
for(const output of [proofJs,proofC]){const compile=spawnSync("bun",[join(core,"bend2/comp.ts"),join(packageDirectory,"belote_proofs_test.bend"),"--to",output],{cwd:core,encoding:"utf8"});if(compile.status!==0)throw new Error(`Belote proof entry did not emit ${output}:\n${compile.stdout}${compile.stderr}`);}
const proofJsRun=spawnSync("bun",[proofJs],{cwd:core,encoding:"utf8"});if(proofJsRun.status!==0||proofJsRun.stdout.trim()!=="True{}")throw new Error(`Belote proof JS failed:\n${proofJsRun.stdout}${proofJsRun.stderr}`);
const proofNativeBuild=spawnSync("clang",["-O2",proofC,"-o",proofBin],{cwd:core,encoding:"utf8"});if(proofNativeBuild.status!==0)throw new Error(`Belote proof C failed to build:\n${proofNativeBuild.stdout}${proofNativeBuild.stderr}`);
const proofNativeRun=spawnSync(proofBin,["--parallel","off","--gpu","off"],{cwd:core,encoding:"utf8"});if(proofNativeRun.status!==0||!/^True\{\}(?:\n|$)/.test(proofNativeRun.stdout))throw new Error(`Belote proof native run failed:\n${proofNativeRun.stdout}${proofNativeRun.stderr}`);
if(!html.includes('src="belote_data.js"')||!html.includes("Bend2 Core now has standard IO"))throw new Error("relative artifact or Core boundary note missing");
for(const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)){if(match[1].trim())new Function(match[1]);}
const context={globalThis:{}};vm.runInNewContext(generated,context,{filename:"belote_data.js"});
const report=context.globalThis.BEND2_BELOTE_DATA;
if(!report||report.$!=="BeloteReport"||report.$4!==true)throw new Error("missing or invalid BeloteReport");
const audit=report.$11;
if(!audit||audit.$!=="BeloteVerificationAudit"||audit.$6!==119||audit.$7!==4||!audit.$3.includes("follow-suit"))throw new Error("missing or invalid Core verification audit");
const list=xs=>{const out=[];while(xs&&xs.$==="Con"){out.push(xs.$0);xs=xs.$1;}return out;};
const steps=list(report.$10), initial=list(steps[0].$8), all=initial.flatMap(p=>list(p.$3));
if(steps.length!==36)throw new Error(`expected 36 observer steps, got ${steps.length}`);
if(initial.length!==4||initial.some(p=>list(p.$3).length!==8)||new Set(all).size!==32)throw new Error("deal is not four disjoint eight-card hands");
const plays=steps.filter(s=>s.$3==="lead"||s.$3==="play"||s.$3==="complete trick");if(plays.length!==32)throw new Error("hand does not contain 32 plays");
const hands=initial.map(p=>list(p.$3)), trump=report.$3, trumpStrength=[0,1,6,7,2,3,4,5], plainStrength=[0,1,2,3,4,5,6,7];
const suit=c=>Math.floor(c/8), strength=c=>(suit(c)===trump?trumpStrength:plainStrength)[c%8];
const winner=trick=>{let w=0;for(let i=1;i<trick.length;i++){const a=trick[i].card,b=trick[w].card;if((suit(a)===trump&&suit(b)!==trump)||(suit(a)===suit(b)&&strength(a)>strength(b)))w=i;}return trick[w].seat;};
const legal=(hand,trick,seat)=>{if(!trick.length)return hand;const lead=suit(trick[0].card),same=hand.filter(c=>suit(c)===lead);if(same.length){if(lead!==trump)return same;const top=Math.max(...trick.filter(x=>suit(x.card)===trump).map(x=>strength(x.card))),over=same.filter(c=>strength(c)>top);return over.length?over:same;}if(winner(trick)===(seat+2)%4)return hand;const trumps=hand.filter(c=>suit(c)===trump);if(!trumps.length)return hand;const top=Math.max(-1,...trick.filter(x=>suit(x.card)===trump).map(x=>strength(x.card))),over=trumps.filter(c=>strength(c)>top);return over.length?over:trumps;};
const value=c=>suit(c)===trump?[0,0,14,20,3,4,10,11][c%8]:[0,0,0,2,3,4,10,11][c%8];
let leader=0,trick=[],points=[0,0];for(let i=0;i<plays.length;i++){const s=plays[i],seat=s.$2,card=s.$4,expected=(leader+trick.length)%4;if(seat!==expected)throw new Error(`play ${i}: actor ${seat}, expected ${expected}`);if(!legal(hands[seat],trick,seat).includes(card))throw new Error(`play ${i}: illegal card ${card}`);hands[seat].splice(hands[seat].indexOf(card),1);trick.push({seat,card});if(list(s.$9).length!==trick.length)throw new Error(`play ${i}: Bend trick table disagrees`);if(trick.length===4){const w=winner(trick),p=trick.reduce((n,x)=>n+value(x.card),0)+(i===31?10:0);points[w%2]+=p;leader=w;trick=[];}}
if(points[0]!==47||points[1]!==115||report.$5!==47||report.$6!==115)throw new Error(`score mismatch: ${points}`);
if(hands.some(h=>h.length))throw new Error("cards remain after eight tricks");
if(!plays[8].$1.includes("must cut")||!plays[10].$1.includes("must overtrump"))throw new Error("cut/overtrump observer notes missing");
console.log("Bend2 Core Belote artifact: deal, bidding, 32 legal plays, 47-115 score, 3 semantic conservation theorems, 1 structural lemma, and 119 closed certificates verified");
