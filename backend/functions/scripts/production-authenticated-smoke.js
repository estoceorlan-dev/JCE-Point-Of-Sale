"use strict";

// Explicit production-only smoke probe. It creates a temporary verified Firebase
// identity and App Check debug token, proves the authenticated callable reaches
// Cloud SQL, then removes both identities. It never creates application/business
// records and never prints credentials or tokens.
const assert = require("node:assert/strict");
const {randomBytes, randomUUID} = require("node:crypto");
const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getStorage} = require("firebase-admin/storage");
const {GoogleAuth} = require("google-auth-library");

function required(environment, name) {
  const value = environment[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function loadProductionSmokeConfig(environment) {
  const projectId = required(environment, "JCE_PRODUCTION_PROJECT");
  const approvedProjectId = required(
    environment,
    "JCE_APPROVED_PRODUCTION_PROJECT_ID",
  );
  const projectNumber = required(environment, "JCE_PRODUCTION_PROJECT_NUMBER");
  const webAppId = required(environment, "JCE_PRODUCTION_WEB_APP_ID");
  const webApiKey = required(environment, "JCE_PRODUCTION_WEB_API_KEY");
  const region = required(environment, "JCE_FUNCTIONS_REGION");

  if (projectId !== approvedProjectId ||
      !/^[a-z][a-z0-9-]*production[a-z0-9-]*$/.test(projectId) ||
      projectId.includes("staging") || projectId.includes("development")) {
    throw new Error("An independently approved production project is required.");
  }
  if (!/^\d+$/.test(projectNumber)) {
    throw new Error("JCE_PRODUCTION_PROJECT_NUMBER must be numeric.");
  }
  if (!webAppId.startsWith(`1:${projectNumber}:web:`)) {
    throw new Error("The web App ID does not belong to the production project.");
  }
  if (!/^[a-z]+-[a-z]+\d+$/.test(region)) {
    throw new Error("JCE_FUNCTIONS_REGION is invalid.");
  }

  return Object.freeze({
    projectId,
    projectNumber,
    webAppId,
    webApiKey,
    region,
    origin: `https://${projectId}.web.app`,
  });
}

async function readJson(response, label) {
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${label} failed (${response.status}/${body.error?.status ||
      body.error?.message || "unknown"}).`);
  }
  return body;
}

async function main() {
  if (!process.argv.includes("--run")) {
    throw new Error("--run explicitly enables temporary production identities.");
  }
  const config = loadProductionSmokeConfig(process.env);
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const googleClient = await auth.getClient();
  googleClient.quotaProjectId = config.projectId;

  const appPath = `projects/${config.projectNumber}/apps/${config.webAppId}`;
  const appCheckBase = "https://firebaseappcheck.googleapis.com/v1";
  const adminApp = initializeApp({
    credential: applicationDefault(),
    projectId: config.projectId,
  }, `production-smoke-${randomUUID()}`);
  const firebaseAuth = getAuth(adminApp);
  const fixtureId = randomUUID();
  const uid = `production-smoke-${fixtureId}`;
  const email = `production-smoke-${fixtureId}@example.invalid`;
  const password = `Qa!9${randomBytes(32).toString("base64url")}`;
  let debugTokenName;
  let userCreated = false;
  let debugTokenCreated = false;
  let storageProbeAttempted = false;
  const probeBucket = `${config.projectId}.firebasestorage.app`;
  const probePath = `users/${uid}/product-images/smoke-upload-${fixtureId}`;

  try {
    const debugToken = randomUUID();
    const createdDebugToken = await googleClient.request({
      method: "POST",
      url: `${appCheckBase}/${appPath}/debugTokens`,
      headers: {"x-goog-user-project": config.projectId},
      data: {
        displayName: `production-smoke-${fixtureId.slice(0, 8)}`,
        token: debugToken,
      },
    });
    debugTokenName = createdDebugToken.data.name;
    assert.equal(typeof debugTokenName, "string");
    debugTokenCreated = true;

    const exchangeResponse = await fetch(
      `${appCheckBase}/${appPath}:exchangeDebugToken?key=${encodeURIComponent(config.webApiKey)}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Origin: config.origin,
          Referer: `${config.origin}/`,
        },
        body: JSON.stringify({debugToken}),
        signal: AbortSignal.timeout(30000),
      },
    );
    const exchange = await readJson(exchangeResponse, "App Check exchange");
    assert.equal(typeof exchange.token, "string");

    await firebaseAuth.createUser({
      uid,
      email,
      emailVerified: true,
      password,
      displayName: "JCE POS production synthetic smoke",
      disabled: false,
    });
    userCreated = true;

    const signInResponse = await fetch(
      "https://identitytoolkit.googleapis.com/v1/" +
        `accounts:signInWithPassword?key=${encodeURIComponent(config.webApiKey)}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Firebase-AppCheck": exchange.token,
          Origin: config.origin,
          Referer: `${config.origin}/`,
        },
        body: JSON.stringify({email, password, returnSecureToken: true}),
        signal: AbortSignal.timeout(30000),
      },
    );
    const signIn = await readJson(signInResponse, "Production sign-in");
    assert.equal(signIn.localId, uid);
    assert.equal(typeof signIn.idToken, "string");

    const callableResponse = await fetch(
      `https://${config.region}-${config.projectId}.cloudfunctions.net/` +
        "getMyAccessProfile",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${signIn.idToken}`,
          "X-Firebase-AppCheck": exchange.token,
          Origin: config.origin,
        },
        body: JSON.stringify({data: {}}),
        signal: AbortSignal.timeout(60000),
      },
    );
    const callableBody = await callableResponse.json();
    assert.notEqual(callableResponse.status, 200);
    assert.equal(callableBody.error?.status, "NOT_FOUND");
    assert.equal(
      callableBody.error?.message,
      "No active JCE POS access profile is available.",
    );
    console.log(JSON.stringify({
      check: "verified Auth + enforced App Check + callable + Cloud SQL denial",
      passed: true,
      businessWrites: 0,
    }));

    // Synthetic identifiers cannot address an existing business record. These
    // checks prove the deployed manager/command handlers deny an unassigned user.
    const scope = {
      organizationId: `smoke-org-${fixtureId}`,
      branchId: `smoke-branch-${fixtureId}`,
      deviceId: `smoke-device-${fixtureId}`,
    };
    const deniedCalls = [
      ["authorizeRegisterClaimResolution", {
        ...scope,
        conflictId: `smoke-conflict-${fixtureId}`,
        targetRegisterId: `smoke-register-${fixtureId}`,
        requestedByUserId: `smoke-cashier-${fixtureId}`,
        nonce: randomUUID(),
      }, "A manager with registers.manage is required."],
      ["applyRemoteCommand", {
        ...scope,
        operationId: `smoke-operation-${fixtureId}`,
        commandType: "register.claim.resolve",
        aggregateType: "register_claim",
        aggregateId: `smoke-conflict-${fixtureId}`,
        payload: {},
      }, "The authenticated user is not assigned to this organization and branch."],
      ["finalizeProductImage", {
        ...scope,
        operationId: `smoke-image-operation-${fixtureId}`,
        productId: `smoke-product-${fixtureId}`,
        imageId: `smoke-image-${fixtureId}`,
        bytesBase64: "iVBORw0KGgo=",
        contentType: "image/png",
      }, "The authenticated user is not assigned to this organization and branch."],
    ];
    for (const [functionName, data, expectedMessage] of deniedCalls) {
      const response = await fetch(
        `https://${config.region}-${config.projectId}.cloudfunctions.net/${functionName}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${signIn.idToken}`,
            "X-Firebase-AppCheck": exchange.token,
            Origin: config.origin,
          },
          body: JSON.stringify({data}),
          signal: AbortSignal.timeout(60000),
        },
      );
      const body = await response.json();
      assert.equal(response.status, 403, functionName);
      assert.equal(body.error?.status, "PERMISSION_DENIED", functionName);
      assert.equal(body.error?.message, expectedMessage, functionName);
      console.log(JSON.stringify({check: `${functionName}: unassigned identity denied`,
        passed: true, businessWrites: 0}));
    }

    if (process.argv.includes("--check-usage")) {
      storageProbeAttempted = true;
      const upload = await fetch(
        `https://firebasestorage.googleapis.com/v0/b/${probeBucket}/o?uploadType=media&name=${encodeURIComponent(probePath)}`,
        {method: "POST", headers: {"Content-Type": "image/png",
          Authorization: `Firebase ${signIn.idToken}`, "X-Firebase-AppCheck": exchange.token,
          Origin: config.origin}, body: Buffer.from("iVBORw0KGgo=", "base64"),
        signal: AbortSignal.timeout(30000)});
      assert.equal(upload.status, 403, "Direct Storage upload must be denied");
      console.log(JSON.stringify({check: "direct Storage upload cannot bypass usage controls", passed: true}));
      let throttled = false;
      for (let attempt = 0; attempt < 65; attempt++) {
        const response = await fetch(
          `https://${config.region}-${config.projectId}.cloudfunctions.net/getMyAccessProfile`,
          {method: "POST", headers: {"Content-Type": "application/json",
            Authorization: `Bearer ${signIn.idToken}`, "X-Firebase-AppCheck": exchange.token,
            Origin: config.origin}, body: JSON.stringify({data: {}}),
          signal: AbortSignal.timeout(60000)});
        const body = await response.json();
        if (response.status === 429) {
          assert.equal(body.error?.status, "RESOURCE_EXHAUSTED");
          assert.ok(body.error.details.retryAfterSeconds >= 1 && body.error.details.retryAfterSeconds <= 60);
          throttled = true;
          break;
        }
        assert.equal(body.error?.status, "NOT_FOUND");
      }
      assert.equal(throttled, true, "The live access-profile rate limit must activate");
      console.log(JSON.stringify({check: "live authenticated 429 with retry hint", passed: true}));
    }
  } finally {
    const cleanupErrors = [];
    if (storageProbeAttempted) {
      try {
        await getStorage(adminApp).bucket(probeBucket).file(probePath).delete({ignoreNotFound: true});
        const [exists] = await getStorage(adminApp).bucket(probeBucket).file(probePath).exists();
        assert.equal(exists, false);
      } catch (error) {cleanupErrors.push(`Synthetic Storage probe: ${error.message}`);}
    }
    if (userCreated) {
      try {
        await firebaseAuth.deleteUser(uid);
        await assert.rejects(firebaseAuth.getUser(uid),
          (error) => error.code === "auth/user-not-found");
      } catch (error) {
        cleanupErrors.push(`Firebase user: ${error.message}`);
      }
    }
    if (debugTokenCreated && debugTokenName) {
      try {
        await googleClient.request({
          method: "DELETE",
          url: `${appCheckBase}/${debugTokenName}`,
          headers: {"x-goog-user-project": config.projectId},
        });
        await assert.rejects(googleClient.request({
          method: "GET",
          url: `${appCheckBase}/${debugTokenName}`,
          headers: {"x-goog-user-project": config.projectId},
        }), (error) => error.response?.status === 404);
      } catch (error) {
        cleanupErrors.push(`App Check debug token: ${error.message}`);
      }
    }
    await deleteApp(adminApp);
    if (cleanupErrors.length > 0) {
      throw new Error(`Synthetic identity cleanup failed: ${cleanupErrors.join("; ")}`);
    }
    console.log(JSON.stringify({
      cleanup: "temporary Firebase user and App Check debug token cleanup complete",
      firebaseUserCreated: userCreated,
      appCheckDebugTokenCreated: debugTokenCreated,
    }));
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}

module.exports = {loadProductionSmokeConfig};
