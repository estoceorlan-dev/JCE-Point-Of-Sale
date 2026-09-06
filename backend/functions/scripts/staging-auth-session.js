// Test/operator sessions only. Passwords, ID/refresh tokens and invite links
// remain in memory and must never be printed or persisted by callers.
const fs = require("node:fs/promises");
const path = require("node:path");

async function signInStaging(section) {
  const project = process.env.JCE_STAGING_PROJECT;
  const credentialsPath = process.env.JCE_TEST_CREDENTIALS_FILE;
  if (!/^[a-z0-9-]*staging[a-z0-9-]*$/.test(project || "") || !credentialsPath) {
    throw new Error("Explicit staging project and private test credentials file required.");
  }
  const text = await fs.readFile(credentialsPath, "utf8");
  const block = text.split(/^##\s+/m).find((value) => value.split(/\r?\n/)[0].trim() === section);
  if (!block) throw new Error("Requested test credential section not found.");
  const value = (label) => {
    const line = block.split(/\r?\n/).find((entry) => entry.toLowerCase().includes(`${label}:`));
    if (!line) throw new Error(`Missing test credential field ${label}.`);
    return line.slice(line.indexOf(":") + 1).trim().replace(/^[`*\s]+|[`*\s]+$/g, "");
  };
  return signInStagingIdentity(value("email"), value("password"));
}

async function signInStagingIdentity(email, password) {
  const project = process.env.JCE_STAGING_PROJECT;
  if (!/^[a-z0-9-]*staging[a-z0-9-]*$/.test(project || "")) throw new Error("Explicit staging project required.");
  const options = await fs.readFile(path.resolve(__dirname, "../../../lib/firebase_options_staging.dart"), "utf8");
  if (!options.includes(`projectId: '${project}'`)) throw new Error("Client configuration does not match staging.");
  const apiKey = options.match(/apiKey:\s*'([^']+)'/)?.[1];
  if (!apiKey) throw new Error("No staging client API key found.");
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {
    method: "POST", headers: {"Content-Type": "application/json"},
    body: JSON.stringify({email, password, returnSecureToken: true}),
    signal: AbortSignal.timeout(30000),
  });
  const result = await response.json();
  if (!response.ok) throw new Error(`Staging sign-in failed: ${result.error?.message || response.status}`);
  const claims = JSON.parse(Buffer.from(result.idToken.split(".")[1], "base64url").toString("utf8"));
  if (claims.aud !== project || claims.sub !== result.localId) throw new Error("Unexpected token project/identity.");
  return {uid: result.localId, idToken: result.idToken, refreshToken: result.refreshToken, apiKey};
}

async function callStaging(session, name, data) {
  const project = process.env.JCE_STAGING_PROJECT;
  const region = process.env.JCE_FUNCTIONS_REGION;
  if (!/^[a-z0-9-]*staging[a-z0-9-]*$/.test(project || "") ||
      !/^[a-z0-9-]+$/.test(region || "") || !/^[A-Za-z0-9]+$/.test(name)) {
    throw new Error("Invalid staging callable target.");
  }
  const response = await fetch(`https://${region}-${project}.cloudfunctions.net/${name}`, {
    method: "POST", headers: {"Content-Type": "application/json", Authorization: `Bearer ${session.idToken}`},
    body: JSON.stringify({data}), signal: AbortSignal.timeout(60000),
  });
  const body = response.headers.get("content-type")?.includes("application/json") ? await response.json() : {};
  return {httpStatus: response.status, error: body.error, result: body.result};
}
module.exports = {signInStaging, signInStagingIdentity, callStaging};
