import assert from "node:assert/strict";
import test from "node:test";
import {HttpsError, type CallableRequest} from "firebase-functions/v2/https";

import {requireRecentVerifiedUser, requireVerifiedUser} from "./callable_identity";

function request(token: Record<string, unknown> = {}): CallableRequest<unknown> {
  return {auth: {uid: "manager", token: {email_verified: true, ...token}}} as
    CallableRequest<unknown>;
}

test("identity rejects missing authentication and unverified email", () => {
  assert.throws(() => requireVerifiedUser({} as CallableRequest<unknown>),
    (error) => error instanceof HttpsError && error.code === "unauthenticated");
  for (const email_verified of [false, undefined, null, "true", 1]) {
    assert.throws(() => requireVerifiedUser(request({email_verified})),
      (error) => error instanceof HttpsError && error.code === "permission-denied");
  }
  assert.equal(requireVerifiedUser(request()), "manager");
});

test("sensitive approval accepts a verified sign-in up to five minutes old", () => {
  for (const age of [0, 1, 299, 300]) {
    assert.equal(requireRecentVerifiedUser(request({auth_time: 1000 - age}), 1000),
      "manager");
  }
});

test("sensitive approval rejects stale, future, missing and malformed auth times", () => {
  for (const auth_time of [699, 1001, 0, -1, 999.5, "999", null, undefined, NaN,
    Infinity]) {
    assert.throws(() => requireRecentVerifiedUser(request({auth_time}), 1000),
      (error) => error instanceof HttpsError && error.code === "unauthenticated" &&
        (error.details as {reason: string}).reason === "recent-authentication-required");
  }
});

test("refreshing an old sign-in token does not authorize a sensitive approval", () => {
  assert.throws(() => requireRecentVerifiedUser(request({auth_time: 699, iat: 1000}),
    1000), (error) => error instanceof HttpsError && error.code === "unauthenticated");
  assert.throws(() => requireRecentVerifiedUser(request({auth_time: 1000,
    email_verified: false}), 1000),
  (error) => error instanceof HttpsError && error.code === "permission-denied");
});
