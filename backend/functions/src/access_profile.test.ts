import assert from "node:assert/strict";
import test from "node:test";
import type { PoolClient } from "pg";

import { registerDeviceForUser } from "./access_profile.js";

test("an authenticated user updates last-seen device metadata without taking ownership", async () => {
  const statements: string[] = [];
  const client = {
    query: async (query: string, values: unknown[]) => {
      const sql = query.replace(/\s+/g, " ").trim();
      statements.push(sql);
      if (sql.startsWith("SELECT au.id AS app_user_id")) {
        assert.deepEqual(values, [
          "firebase-admin",
          "organization",
          "branch",
        ]);
        return { rows: [{ app_user_id: "admin-user" }], rowCount: 1 };
      }
      assert.ok(sql.startsWith("INSERT INTO devices"));
      assert.ok(
        sql.includes(
          "last_seen_by_user_id = EXCLUDED.last_seen_by_user_id",
        ),
      );
      assert.ok(!sql.includes("user_id = EXCLUDED.user_id"));
      assert.ok(!sql.includes("WHERE devices.user_id = EXCLUDED.user_id"));
      assert.deepEqual(values, [
        "device-a",
        "organization",
        "branch",
        "admin-user",
        "windows",
      ]);
      return { rows: [{ id: "device-a" }], rowCount: 1 };
    },
  } as unknown as PoolClient;

  await registerDeviceForUser(client, {
    firebaseUid: "firebase-admin",
    deviceId: "device-a",
    platform: "windows",
    organizationId: "organization",
    branchId: "branch",
  });

  assert.equal(statements.length, 2);
});
