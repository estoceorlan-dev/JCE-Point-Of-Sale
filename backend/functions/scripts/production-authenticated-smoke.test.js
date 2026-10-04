"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  loadProductionSmokeConfig,
} = require("./production-authenticated-smoke");

function validEnvironment() {
  return {
    JCE_PRODUCTION_PROJECT: "jce-pos-production-259528",
    JCE_APPROVED_PRODUCTION_PROJECT_ID: "jce-pos-production-259528",
    JCE_PRODUCTION_PROJECT_NUMBER: "68924675797",
    JCE_PRODUCTION_WEB_APP_ID: "1:68924675797:web:0123456789abcdef",
    JCE_PRODUCTION_WEB_API_KEY: "public-client-key",
    JCE_FUNCTIONS_REGION: "asia-southeast1",
  };
}

test("accepts an independently approved production smoke target", () => {
  const config = loadProductionSmokeConfig(validEnvironment());
  assert.equal(config.projectId, "jce-pos-production-259528");
  assert.equal(config.origin, "https://jce-pos-production-259528.web.app");
});

test("rejects a cross-project production smoke target", () => {
  const environment = validEnvironment();
  environment.JCE_APPROVED_PRODUCTION_PROJECT_ID = "other-production";
  assert.throws(
    () => loadProductionSmokeConfig(environment),
    /independently approved production project/,
  );
});

test("rejects a web app from another Firebase project number", () => {
  const environment = validEnvironment();
  environment.JCE_PRODUCTION_WEB_APP_ID = "1:111111111111:web:0123456789abcdef";
  assert.throws(
    () => loadProductionSmokeConfig(environment),
    /web App ID does not belong/,
  );
});
