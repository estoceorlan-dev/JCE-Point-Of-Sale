import assert from "node:assert/strict";
import test from "node:test";

import {
  isDatabaseAuthenticationFailure,
  isDatabasePoolFresh,
  maximumPoolAgeMilliseconds,
} from "./database.js";

test("database pools renew before IAM credentials reach one hour", () => {
  const input = {
    poolExists: true,
    activeConfigKey: "staging",
    requestedConfigKey: "staging",
    createdAt: 1000,
  };

  assert.equal(isDatabasePoolFresh({
    ...input,
    now: input.createdAt + maximumPoolAgeMilliseconds - 1,
  }), true);
  assert.equal(isDatabasePoolFresh({
    ...input,
    now: input.createdAt + maximumPoolAgeMilliseconds,
  }), false);
  assert.equal(isDatabasePoolFresh({
    ...input,
    requestedConfigKey: "production",
    now: input.createdAt,
  }), false);
});

test("only PostgreSQL authentication failures trigger a fresh connection retry", () => {
  assert.equal(isDatabaseAuthenticationFailure({code: "28000"}), true);
  assert.equal(isDatabaseAuthenticationFailure({code: "42P18"}), false);
  assert.equal(isDatabaseAuthenticationFailure(new Error("network")), false);
});
