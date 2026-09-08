import assert from "node:assert/strict";
import test from "node:test";
import {PoolClient} from "pg";
import {acceptStaffInvite, bindStaffIdentity, loadInvitedStaff, StaffInviteError} from "../staff_invites";

const input = {
  actorFirebaseUid: "admin-auth", organizationId: "org", userId: "staff",
  targetFirebaseUid: "staff-auth", targetEmail: "staff@example.test",
};
const result = (rows: Record<string, unknown>[]) => ({rows, rowCount: rows.length});
function client(query: (sql: string, values: unknown[]) => unknown): PoolClient {
  return {query: async (sql: string, values: unknown[] = []) => query(sql.replace(/\s+/g, " ").trim(), values)} as unknown as PoolClient;
}
const denied = (reason: string) => (error: unknown) => error instanceof StaffInviteError && error.reason === reason;

test("binding checks current permission after the access lock and rolls back revocation", async () => {
  const statements: string[] = [];
  const db = client((sql, values) => {
    statements.push(sql);
    if (sql.includes("pg_advisory_xact_lock")) {
      assert.deepEqual(values, ["access-administration:org"]);
    }
    if (sql.startsWith("SELECT 1 FROM app_users")) {
      assert.ok(statements[1].includes("pg_advisory_xact_lock"));
      assert.ok(sql.includes("ura.branch_id IS NULL"));
      assert.ok(sql.includes("o.is_active = true AND o.deleted_at IS NULL"));
      assert.deepEqual(values, ["admin-auth", "org", "users.manage"]);
      return result([]); // Permission removed while identity lookup was in flight.
    }
    assert.ok(!sql.startsWith("UPDATE") && !sql.startsWith("INSERT"));
    return result([]);
  });
  await assert.rejects(bindStaffIdentity(db, input), denied("permission-denied"));
  assert.equal(statements[0], "BEGIN");
  assert.equal(statements.at(-1), "ROLLBACK");
});

test("binding rejects an invitation changed or disabled after identity lookup", async () => {
  const statements: string[] = [];
  const db = client((sql, values) => {
    statements.push(sql);
    if (sql.startsWith("SELECT 1 FROM app_users")) return result([{}]);
    if (sql.startsWith("UPDATE app_users")) {
      assert.ok(sql.includes("organization_id = $2 AND status = 'invited'"));
      assert.ok(sql.includes("firebase_uid IS NULL OR firebase_uid = $3"));
      assert.ok(sql.includes("lower(email) = lower($4)"));
      assert.deepEqual(values, ["staff", "org", "staff-auth", "staff@example.test"]);
      return result([]);
    }
    assert.ok(!sql.startsWith("INSERT"));
    return result([]);
  });
  await assert.rejects(bindStaffIdentity(db, input), denied("failed-precondition"));
  assert.equal(statements.at(-1), "ROLLBACK");
});

test("successful binding emits atomic lifecycle metadata without invite secrets", async () => {
  const statements: string[] = [];
  const db = client((sql, values) => {
    statements.push(sql);
    if (sql.startsWith("SELECT 1 FROM app_users")) return result([{}]);
    if (sql.startsWith("SELECT id FROM app_users")) return result([{id: "admin"}]);
    if (sql.startsWith("UPDATE app_users")) return result([{
      id: "staff", organization_id: "org", firebase_uid: "staff-auth",
      email: "staff@example.test", display_name: "Staff", status: "invited", version: 1,
      created_at: new Date("2026-09-07T00:00:00Z"), updated_at: new Date("2026-09-07T00:00:00Z"),
    }]);
    if (sql.startsWith("INSERT")) {
      assert.ok(!JSON.stringify(values).includes("inviteUrl"));
      assert.ok(!JSON.stringify(values).includes("password"));
    }
    return result([]);
  });
  assert.deepEqual(await bindStaffIdentity(db, input), {email: "staff@example.test", displayName: "Staff"});
  assert.equal(statements.filter((sql) => sql.startsWith("INSERT")).length, 2);
  assert.equal(statements.at(-1), "COMMIT");
});

test("inactive organization cannot expose an invitation", async () => {
  const db = client((sql) => {
    assert.ok(sql.includes("JOIN organizations o"));
    assert.ok(sql.includes("o.is_active = true AND o.deleted_at IS NULL"));
    return result([]);
  });
  await assert.rejects(loadInvitedStaff(db, input), denied("permission-denied"));
});

for (const active of [false, true]) {
  test(`acceptance replay ${active ? "succeeds for matching active identity" : "rejects mismatched or inactive organization identity"}`, async () => {
    const statements: string[] = [];
    const db = client((sql, values) => {
      statements.push(sql);
      if (sql.startsWith("UPDATE")) {
        assert.ok(sql.includes("firebase_uid = $2") && sql.includes("lower(email) = lower($3)"));
        return result([]);
      }
      if (sql.startsWith("SELECT 1")) {
        assert.ok(sql.includes("JOIN organizations o") && sql.includes("o.is_active = true"));
        assert.ok(sql.includes("au.status = 'active'"));
        assert.deepEqual(values, ["org", "staff-auth", "staff@example.test"]);
        return result(active ? [{}] : []);
      }
      assert.ok(!sql.startsWith("INSERT"));
      return result([]);
    });
    const acceptance = acceptStaffInvite(db, {firebaseUid: "staff-auth", email: "staff@example.test", organizationId: "org"});
    if (active) assert.equal(await acceptance, 0);
    else await assert.rejects(acceptance, denied("failed-precondition"));
    assert.equal(statements.at(-1), active ? "COMMIT" : "ROLLBACK");
  });
}
