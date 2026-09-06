import assert from "node:assert/strict";
import test from "node:test";
import {PoolClient} from "pg";
import {authorizeCommand} from "./command_authorization";
import {applyBranchCommand} from "./branch_commands";
import {requireSafeAccessState} from "./access_state_guard";
import {AuthorizedCommand, RemoteCommandError, RemoteCommandInput} from "./command_types";

const permissions = ["branches.manage", "roles.manage", "users.manage"];
const input: RemoteCommandInput = {
  firebaseUid: "firebase-admin", organizationId: "org", branchId: "active",
  operationId: "op", commandType: "branch.create", aggregateType: "branch",
  aggregateId: "target", payload: {id: "target", code: "NEW", name: "New branch", timezone: "Asia/Manila"},
};
const authorized: AuthorizedCommand = {...input, actorUserId: "admin", permissions: new Set(permissions)};
const result = (rows: Record<string, unknown>[]) => ({rows, rowCount: rows.length});
function client(query: (sql: string, values?: unknown[]) => unknown): PoolClient {
  return {query: async (sql: string, values?: unknown[]) => query(sql.replace(/\s+/g, " ").trim(), values)} as unknown as PoolClient;
}
function code(expected: string) {
  return (error: unknown) => error instanceof RemoteCommandError && error.code === expected;
}

for (const commandType of ["branch.create", "branch.update", "branch.archive", "branch.restore", "user.invite", "user.assignments.replace", "role.create", "role.update"]) {
  test(`branch-only assignment cannot authorize ${commandType}`, async () => {
    let scoped = false;
    const database = client((sql) => {
      if (sql.endsWith("FOR SHARE")) return result([{id: "active"}]);
      scoped = sql.includes("AND (ura.branch_id IS NULL)");
      assert.ok(sql.includes("r.organization_id = ura.organization_id"));
      return result(scoped ? [] : [{actor_user_id: "admin", permission_codes: permissions}]);
    });
    await assert.rejects(authorizeCommand(database, {...input, commandType}), code("permission-denied"));
    assert.ok(scoped);
  });
}
test("organization role authorizes the managed record independently of active context", async () => {
  const database = client((sql, values) => {
    if (sql.endsWith("FOR SHARE")) return result([{id: "active"}]);
    assert.deepEqual(values, ["firebase-admin", "org", "active"]);
    return result([{actor_user_id: "admin", permission_codes: permissions}]);
  });
  const command = await authorizeCommand(database, input);
  assert.equal(command.branchId, "active");
  assert.equal(command.aggregateId, "target");
});
test("invalid timezone and contacts are rejected before branch insertion", async () => {
  const database = client(() => {throw new Error("No write expected");});
  for (const invalid of [{timezone: "Imaginary/City"}, {email: "invalid"}, {phone: "abcdefg"}, {receiptDisplayName: "x".repeat(81)}]) {
    await assert.rejects(applyBranchCommand(database, {...authorized, payload: {...input.payload, ...invalid}}), code("invalid-argument"));
  }
});
test("archival locks the target before checking active operations", async () => {
  const statements: string[] = [];
  const database = client((sql) => {
    statements.push(sql);
    if (sql.includes("pg_advisory_xact_lock")) return result([]);
    if (sql.endsWith("FOR UPDATE")) return result([{id: "target"}]);
    if (sql.includes("active_count")) return result([{active_count: "2", has_shift: true, has_count: false, has_transfer: false}]);
    throw new Error("A guarded branch must not be updated");
  });
  await assert.rejects(applyBranchCommand(database, {
    ...authorized, commandType: "branch.archive", payload: {expectedVersion: 0},
  }), code("failed-precondition"));
  assert.ok(statements[0].includes("pg_advisory_xact_lock"));
  assert.ok(statements[1].endsWith("FOR UPDATE"));
  assert.ok(statements[2].includes("active_count"));
});
test("current-branch and foreign-record archival are rejected", async () => {
  const database = client(() => result([]));
  await assert.rejects(applyBranchCommand(database, {
    ...authorized, commandType: "branch.archive", aggregateId: "active", payload: {expectedVersion: 0},
  }), code("failed-precondition"));
  await assert.rejects(applyBranchCommand(database, {
    ...authorized, commandType: "branch.archive", payload: {expectedVersion: 0},
  }), code("not-found"));
});
test("self-lockout is rejected even when another full administrator remains", async () => {
  const database = client(() => result([
    {user_id: "admin", permission_codes: ["users.manage"]},
    {user_id: "other-admin", permission_codes: permissions},
  ]));
  await assert.rejects(requireSafeAccessState(database, authorized), /your own administration access/);
});
test("no remaining full administrator is rejected", async () => {
  const database = client(() => result([{user_id: "admin", permission_codes: ["roles.manage"]}]));
  await assert.rejects(requireSafeAccessState(database, {
    ...authorized, permissions: new Set(["roles.manage"]),
  }), /at least one active full organization administrator/);
});
test("permission unions across roles preserve administration access", async () => {
  await requireSafeAccessState(client(() => result([{user_id: "admin", permission_codes: permissions}])), authorized);
});
