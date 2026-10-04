import assert from "node:assert/strict";
import test from "node:test";

import {enforceRateLimit, RateLimitExceededError} from "./api_rate_limiter";

test("allows a request within the configured limit without storing the UID", async () => {
  const calls: {sql: string; values?: unknown[]}[] = [];
  const client = {
    async query(sql: string, values?: unknown[]) {
      calls.push({sql, values});
      if (sql.includes("INSERT INTO api_rate_limit_windows")) {
        return {rows: [{request_count: 2, retry_after_seconds: 41}]};
      }
      return {rows: []};
    },
  };

  await enforceRateLimit(client as never, {
    firebaseUid: "firebase-user-123",
    scope: "remote_command",
    maximumRequests: 10,
    windowSeconds: 60,
  });

  assert.equal(calls.length, 1);
  assert.notEqual(calls[0].values?.[0], "firebase-user-123");
  assert.match(String(calls[0].values?.[0]), /^[a-f0-9]{64}$/);
});

test("rejects a request over the configured limit", async () => {
  const client = {
    async query(sql: string) {
      if (sql.includes("INSERT INTO api_rate_limit_windows")) {
        return {rows: [{request_count: 11, retry_after_seconds: 17}]};
      }
      return {rows: []};
    },
  };

  await assert.rejects(
    enforceRateLimit(client as never, {
      firebaseUid: "firebase-user-123",
      scope: "remote_command",
      maximumRequests: 10,
      windowSeconds: 60,
    }),
    (error: unknown) =>
      error instanceof RateLimitExceededError && error.retryAfterSeconds === 17,
  );
});

test("rejects invalid server policy before querying", async () => {
  const client = {query: async () => assert.fail("query must not run")};
  await assert.rejects(
    enforceRateLimit(client as never, {
      firebaseUid: "user",
      scope: "invalid scope",
      maximumRequests: 10,
      windowSeconds: 60,
    }),
    /policy is invalid/,
  );
});

