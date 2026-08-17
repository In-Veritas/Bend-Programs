import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const html = fs.readFileSync(new URL("./index.html", import.meta.url), "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match => match[1]);
assert.ok(scripts.length, "the poker client needs an inline script");
for (const source of scripts) new vm.Script(source, { filename: "poker-inline.js" });

for (const required of [
  "Texas Hold'em", "Omaha", "Fold", "Check", "Call", "Raise",
  'type="range"', "estimated showdown equity", "Invite player",
  "/core/poker", "No private cards used", "visible-information rollouts"
]) assert.ok(html.includes(required), `missing client surface: ${required}`);

assert.match(html, /function omaha\(/, "Omaha must enforce its separate evaluator");
assert.match(html, /function simulate\(/, "visible-information odds simulation is missing");
assert.doesNotMatch(html, /players\[[^\]]+\]\.cards[^\n]+players\[[^\]]+\]\.cards/, "client should not combine received opponent holes");
console.log("Poker client syntax, actions, runtime switch, invitation, and odds surfaces passed.");
