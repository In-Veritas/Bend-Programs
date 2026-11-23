import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

export const EXPECTED_CORE = "c5d69a1";
export const list = xs => { const out=[]; while(xs?.$==="Con") { out.push(xs.$0); xs=xs.$1; } return out; };
export function packageContext(moduleUrl) {
  const here=dirname(fileURLToPath(moduleUrl));
  const core=resolve(process.env.BEND2_CORE||join(here,"../../../../bend2-core"));
  const revision=spawnSync("git",["rev-parse","HEAD"],{cwd:core,encoding:"utf8"});
  if(revision.status!==0||!revision.stdout.trim().startsWith(EXPECTED_CORE))throw new Error(`expected bend2-core ${EXPECTED_CORE}, got ${revision.stdout.trim()||revision.stderr.trim()}`);
  return {here,core,revision:revision.stdout.trim()};
}
export function loadData(here,file,globalName) {
  const context={globalThis:{}};vm.runInNewContext(readFileSync(join(here,file),"utf8"),context,{filename:file});return context.globalThis[globalName];
}
export function verifyCoreEntries({here,core},entries) {
  for(const entry of entries){
    const source=join(here,entry),text=readFileSync(source,"utf8");if(/^\s*#\[halts\]/m.test(text))throw new Error(`${entry} uses the removed #[halts] spelling`);
    const stem=entry.replace(/\.bend$/,""),js=join(process.env.TMPDIR||"/tmp",`${stem}.verified.js`),c=join(process.env.TMPDIR||"/tmp",`${stem}.verified.c`),bin=join(process.env.TMPDIR||"/tmp",`${stem}.verified`);
    for(const out of [js,c]){const run=spawnSync("bun",[join(core,"bend2/comp.ts"),source,"--to",out],{cwd:core,encoding:"utf8"});if(run.status!==0)throw new Error(`${entry} failed emission:\n${run.stdout}${run.stderr}`)}
    const jsRun=spawnSync("bun",[js],{cwd:core,encoding:"utf8"});if(jsRun.status!==0||jsRun.stdout.trim()!=="True{}")throw new Error(`${entry} JS failed:\n${jsRun.stdout}${jsRun.stderr}`);
    const cc=spawnSync("clang",["-O2",c,"-o",bin],{encoding:"utf8"});if(cc.status!==0)throw new Error(`${entry} C failed:\n${cc.stdout}${cc.stderr}`);const native=spawnSync(bin,["--parallel","off","--gpu","off"],{encoding:"utf8"});if(native.status!==0||!/^True\{\}(?:\n|$)/.test(native.stdout))throw new Error(`${entry} native failed:\n${native.stdout}${native.stderr}`);
  }
}
