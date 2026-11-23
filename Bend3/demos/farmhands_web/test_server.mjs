import assert from "node:assert/strict";
import {mkdtemp, readFile} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join, resolve} from "node:path";
import {spawn} from "node:child_process";

const binary = resolve(process.env.FARMHANDS_BIN || "Bend3/demos/farmhands_web/build/web_farmhands");
const port = Number(process.env.FARMHANDS_TEST_PORT || 8195);
const base = `http://127.0.0.1:${port}`;
const dataDir = await mkdtemp(join(tmpdir(), "farmhands-http-"));

function launch() {
  const child = spawn(binary, [], {
    cwd: resolve("."),
    env: {...process.env, FARMHANDS_DATA_DIR: dataDir, FARMHANDS_PORT: String(port)},
    stdio: ["ignore", "pipe", "pipe"],
  });
  let output = "";
  child.stdout.on("data", chunk => output += chunk);
  child.stderr.on("data", chunk => output += chunk);
  return {child, ready: new Promise((resolveReady, reject) => {
    const limit = setTimeout(() => reject(new Error(`server did not start: ${output}`)), 15000);
    const poll = setInterval(() => {
      if (output.includes("Farmhands listening")) {
        clearTimeout(limit); clearInterval(poll); resolveReady();
      } else if (child.exitCode !== null) {
        clearTimeout(limit); clearInterval(poll); reject(new Error(`server exited: ${output}`));
      }
    }, 25);
  })};
}

async function stop(child) {
  if (child.exitCode !== null) return;
  child.kill("SIGTERM");
  await new Promise(resolveDone => child.once("exit", resolveDone));
}

async function post(path, lines) {
  const response = await fetch(`${base}/api/${path}`, {method: "POST", body: lines.join("\n")});
  assert.equal(response.status, 200);
  return response.json();
}

let running = launch();
try {
  await running.ready;
  const accounts = {};
  for (const name of ["owner", "alice", "bob", "carol"]) {
    const result = await post("register", [name, `pass-${name}`]);
    assert.equal(result.ok, 1, result.note);
    accounts[name] = result.token;
  }

  for (const plot of [0, 1, 2]) {
    const planted = await post("plant", [accounts.owner, plot, 1]);
    assert.equal(planted.ok, 1, planted.note);
  }
  await new Promise(resolveWait => setTimeout(resolveWait, 16000));

  assert.equal((await post("steal", [accounts.alice, "owner", 0])).amount, 3);
  assert.equal((await post("steal", [accounts.alice, "owner", 0])).ok, 0, "same visitor stole the same crop twice");
  assert.equal((await post("steal", [accounts.bob, "owner", 0])).amount, 3);
  assert.equal((await post("steal", [accounts.carol, "owner", 0])).amount, 3);
  assert.equal((await post("steal", [accounts.alice, "owner", 1])).amount, 3);
  assert.equal((await post("steal", [accounts.alice, "owner", 2])).ok, 0, "daily two-crop limit was not enforced");
  const harvest = await post("harvest", [accounts.owner, 0]);
  assert.equal(harvest.amount, 3, "owner reserve fell below 25%");

  const credentials = await readFile(join(dataDir, "credentials.csv"), "utf8");
  assert(!credentials.includes("pass-owner"), "CSV contains a plaintext password");
  for (const line of credentials.trim().split("\n").slice(1)) {
    assert.match(line.split(",")[3], /^[0-9a-f]{64}$/);
  }

  await stop(running.child);
  running = launch();
  await running.ready;
  const ownerLogin = await post("login", ["owner", "pass-owner"]);
  assert.equal(ownerLogin.ok, 1, ownerLogin.note);
  assert.equal(ownerLogin.me.inventory.turnip, 3);
  const aliceLogin = await post("login", ["alice", "pass-alice"]);
  assert.equal(aliceLogin.me.inventory.turnip, 6);
  assert.equal((await post("login", ["alice", "wrong-password"])).ok, 0);
  console.log("Farmhands HTTP: auth, CSV restart, crop timing, 25% reserve, per-plot and daily theft limits verified");
} finally {
  await stop(running.child);
}
