import assert from "node:assert/strict";
import test from "node:test";
import {PoolClient} from "pg";
import {loadAdministrationSnapshot} from "../administration_snapshot";

function database(permissions: string[], failRead = false) {
  const statements: string[] = [];
  const client = {query: async (query: string, values?: unknown[]) => {
    const sql = query.replace(/\s+/g, " ").trim();
    statements.push(sql);
    if (/^(BEGIN|COMMIT|ROLLBACK)/.test(sql)) return {rows: [], rowCount: 0};
    if (sql.includes("SELECT DISTINCT rp.permission_code")) {
      assert.ok(sql.includes("ura.branch_id IS NULL"));
      assert.ok(sql.includes("r.organization_id = au.organization_id"));
      assert.ok(sql.includes("o.is_active = true"));
      assert.deepEqual(values?.slice(0, 2), ["uid", "org"]);
      return {rows: permissions.map((permission_code) => ({permission_code})), rowCount: permissions.length};
    }
    assert.deepEqual(values, ["org"]);
    if (failRead) throw new Error("database read failed");
    return {rows: [{id: "record", createdAt: new Date("2026-09-06T00:00:00Z")}], rowCount: 1};
  }} as unknown as PoolClient;
  return {client, statements};
}

for (const permission of ["branches.manage", "registers.manage", "roles.manage", "users.manage", "products.manage"]) {
  test(`snapshot supports organization-wide ${permission} with scoped collections`, async () => {
    const {client, statements} = database([permission]);
    const snapshot = await loadAdministrationSnapshot(client, {firebaseUid: "uid", organizationId: "org"});
    assert.equal(snapshot.branches.length, 1);
    assert.equal(snapshot.users.length, ["roles.manage", "users.manage"].includes(permission) ? 1 : 0);
    assert.equal(snapshot.roles.length, snapshot.users.length);
    assert.equal(snapshot.assignments.length, snapshot.users.length);
    assert.equal(snapshot.registers.length, permission === "products.manage" ? 0 : 1);
    assert.equal(snapshot.taxCategories.length, permission === "products.manage" ? 1 : 0);
    assert.equal(snapshot.branches[0].createdAt, "2026-09-06T00:00:00.000Z");
    assert.equal(statements.at(-1), "COMMIT");
    if (!snapshot.users.length) assert.ok(!statements.some((sql) => sql.includes("FROM app_users WHERE")));
  });
}

test("missing organization-wide permission rejects snapshot without reading directories", async () => {
  const {client, statements} = database([]);
  await assert.rejects(loadAdministrationSnapshot(client, {firebaseUid: "uid", organizationId: "org"}), /organization-wide/);
  assert.equal(statements.length, 3);
  assert.equal(statements.at(-1), "ROLLBACK");
});

test("failed snapshot reads roll back the consistent transaction", async () => {
  const {client, statements} = database(["branches.manage"], true);
  await assert.rejects(loadAdministrationSnapshot(client, {firebaseUid: "uid", organizationId: "org"}), /read failed/);
  assert.equal(statements.at(-1), "ROLLBACK");
});
