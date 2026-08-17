import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const html = fs.readFileSync(
  new URL("./index.html", import.meta.url),
  "utf8",
);
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
assert.ok(scripts.length >= 1, "embedded obfuscator engine not found");
for (const [index, script] of scripts.entries()) {
  new vm.Script(script[1], { filename: `obfuscator-inline-${index}.js` });
}

const context = vm.createContext({ window: {} });
new vm.Script(scripts[0][1], { filename: "obfuscator-engine.js" }).runInContext(
  context,
);
const { obfuscateBend, tokenize } = context.window.BendObfuscator;

const importedRecord = `# no-halt
# removed comment
import HTTP

def response_status(response: HTTP::Response) -> U32:
  match response:
    case Response{status, headers, body}:
      status

def main() -> U32:
  response_status(Response{status: 200, headers: Nil{}, body: "status"})
`;
const transformed = obfuscateBend(importedRecord, {
  stripComments: true,
  explodeNumbers: false,
  splitEligibleFunctions: false,
  insertDecoys: false,
  shuffleGenerated: false,
  chaoticSpacing: false,
  seed: 12345,
});

assert.equal(transformed.diagnostics.filter((item) => item.severity === "error").length, 0);
assert.match(transformed.text, /^# no-halt/m);
assert.doesNotMatch(transformed.text, /removed comment/);
assert.match(transformed.text, /Response\{status, headers, body\}/);
assert.match(transformed.text, /Response\{status: 200, headers: Nil\{\}, body: "status"\}/);
assert.ok(
  transformed.mapping.some(([name]) => name === "response_status"),
  "local function should be renamed",
);
assert.ok(
  transformed.mapping.some(([name]) => name === "response"),
  "local parameter should be renamed",
);
assert.ok(
  !transformed.mapping.some(([name]) => ["status", "headers", "body"].includes(name)),
  "constructor fields must remain stable",
);
assert.ok(
  transformed.mapping.every(([, alias]) => alias.length >= 20),
  "aliases should be conspicuously long rather than compact counters",
);
assert.ok(
  transformed.mapping.every(([, alias]) => /^[a-z_].*[A-Z]/.test(alias)),
  "every alias should have disruptive interior capitalization",
);
assert.ok(
  transformed.mapping.every(
    ([, alias]) =>
      !/administratively|circumlocution|indistinguishable|transmogrified/i.test(
        alias,
      ),
  ),
  "aliases must be random, keyword-like, or a mixture—not verbose English",
);

const qualified = obfuscateBend(
  `import HTTP\n\ndef main() -> U32:\n  HTTP.reply(200, "x", "y")\n`,
  {
    explodeNumbers: false,
    splitEligibleFunctions: false,
    insertDecoys: false,
    chaoticSpacing: false,
    seed: 7,
  },
);
assert.match(qualified.text, /HTTP\.reply\(/, "dot-qualified names are ABI/API names");
assert.ok(
  !qualified.mapping.some(([name]) => name === "reply"),
  "dot-qualified member must never enter the rename map",
);

const numericTokens = tokenize("0x2a 0b101010 0o52 3.1415 6.2e+3 42").tokens;
assert.deepEqual(
  Array.from(
    numericTokens
      .filter((token) => token.type === "number-other")
      .map((token) => token.value),
  ),
  ["0x2a", "0b101010", "0o52", "3.1415", "6.2e+3"],
  "non-decimal-integer forms must remain indivisible protected tokens",
);

assert.equal(
  JSON.stringify(
    tokenize(transformed.text).tokens
      .filter((token) => token.type === "literal")
      .map((token) => token.value),
  ),
  JSON.stringify(
    tokenize(importedRecord).tokens
      .filter((token) => token.type === "literal")
      .map((token) => token.value),
  ),
);

const malformed = obfuscateBend('def main() -> String:\n  "never closed', {
  stripComments: true,
});
assert.ok(
  malformed.diagnostics.some((item) => item.severity === "error"),
  "unterminated literals must block export",
);

const structuralSource = `# no-halt
def add(left: U32, right: U32) -> U32:
  left + right

def main() -> U32:
  add(20, 22)
`;
const structural = obfuscateBend(structuralSource, {
  stripComments: true,
  explodeNumbers: true,
  splitEligibleFunctions: true,
  insertDecoys: true,
  shuffleGenerated: true,
  chaoticSpacing: true,
  seed: 987654321,
});
assert.equal(structural.diagnostics.filter((item) => item.severity === "error").length, 0);
assert.ok(structural.explodedNumbers >= 2, "source and generated expression constants should expand");
assert.equal(structural.splitFunctions, 1, "the non-recursive helper should split");
assert.ok(structural.callLayers >= 2, "one helper becomes a multi-hop call chain");
assert.ok(structural.decoyFunctions >= 2, "aggressive mode adds unreachable helper decoys");
assert.match(structural.text, /\*|\+|-/, "expanded constants should contain arithmetic");
assert.match(structural.text, / {20,}/, "wide mode should create conspicuously large inline gaps");
assert.match(structural.text, /match\s+\(+/, "call wrappers should contain opaque arithmetic selectors");
assert.ok(structural.text.length > structuralSource.length * 2);
assert.equal(
  structural.text,
  obfuscateBend(structuralSource, {
    stripComments: true,
    explodeNumbers: true,
    splitEligibleFunctions: true,
    insertDecoys: true,
    shuffleGenerated: true,
    chaoticSpacing: true,
    seed: 987654321,
  }).text,
  "a recorded seed must reproduce output byte-for-byte",
);
const alternateStructural = obfuscateBend(structuralSource, {
  seed: 987654322,
});
assert.notEqual(
  structural.text,
  alternateStructural.text,
  "a different seed should diversify the surface form",
);

const conservative = obfuscateBend(structuralSource, {
  explodeNumbers: false,
  splitEligibleFunctions: false,
  insertDecoys: false,
  shuffleGenerated: false,
  chaoticSpacing: false,
  seed: 11,
});
assert.equal(conservative.explodedNumbers, 0);
assert.equal(conservative.splitFunctions, 0);
assert.equal(conservative.callLayers, 0);
assert.equal(conservative.decoyFunctions, 0);
if (process.env.BEND_OBFUSCATOR_OUTPUT) {
  fs.writeFileSync(process.env.BEND_OBFUSCATOR_OUTPUT, structural.text);
}
if (process.env.BEND_OBFUSCATOR_OUTPUT_ALT) {
  fs.writeFileSync(
    process.env.BEND_OBFUSCATOR_OUTPUT_ALT,
    alternateStructural.text,
  );
}

console.log("Bend3 obfuscator browser-engine checks passed.");
