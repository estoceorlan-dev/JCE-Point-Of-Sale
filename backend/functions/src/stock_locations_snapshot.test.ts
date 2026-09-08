import assert from "node:assert/strict";
import test from "node:test";
import {PoolClient} from "pg";

import {RemoteCommandError} from "./remote_commands/command_types";
import {loadStockLocationsSnapshot} from "./stock_locations_snapshot";

function database(permissions: string[]) {
  const statements: string[] = [];
  const client = {query: async (query: string, values?: unknown[]) => {
    const sql = query.replace(/\s+/g, " ").trim();
    statements.push(sql);
    if (/^(BEGIN|COMMIT|ROLLBACK)/.test(sql)) return {rows: [], rowCount: 0};
    if (sql.startsWith("SELECT id FROM branches")) {
      assert.ok(sql.endsWith("FOR SHARE"));
      assert.deepEqual(values, ["branch", "organization"]);
      return {rows: [{id: "branch"}], rowCount: 1};
    }
    if (sql.includes("SELECT au.id AS actor_user_id")) {
      return {rows: permissions.length ? [{actor_user_id: "user", permission_codes: permissions}] : [], rowCount: permissions.length ? 1 : 0};
    }
    assert.deepEqual(values, ["organization", "branch"]);
    return {rows: [{
      id: "location",
      organization_id: "organization",
      branch_id: "branch",
      code: "WAREHOUSE",
      name: "Warehouse",
      location_type: "warehouse",
      is_default: true,
      is_active: true,
      version: 3,
      created_at: new Date("2026-09-07T00:00:00Z"),
      updated_at: new Date("2026-09-07T00:00:00Z"),
      deleted_at: null,
    }], rowCount: 1};
  }} as unknown as PoolClient;
  return {client, statements};
}

test("a branch-scoped inventory user receives a consistent location snapshot", async () => {
  const {client, statements} = database(["inventory.manage"]);
  const snapshot = await loadStockLocationsSnapshot(client, {
    firebaseUid: "uid",
    organizationId: "organization",
    branchId: "branch",
  });

  assert.equal(snapshot.schemaVersion, 1);
  assert.equal(snapshot.locations[0].updated_at, "2026-09-07T00:00:00.000Z");
  assert.ok(statements.some((sql) => sql.includes("FROM stock_locations")));
  assert.equal(statements.at(-1), "COMMIT");
});

test("a user without inventory access cannot read locations", async () => {
  const {client, statements} = database([]);
  await assert.rejects(
    loadStockLocationsSnapshot(client, {
      firebaseUid: "uid",
      organizationId: "organization",
      branchId: "branch",
    }),
    (error) => error instanceof RemoteCommandError && error.code === "permission-denied",
  );
  assert.equal(statements.at(-1), "ROLLBACK");
  assert.equal(statements.some((sql) => sql.includes("FROM stock_locations")), false);
});
