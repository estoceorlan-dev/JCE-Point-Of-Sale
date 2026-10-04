import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test from "node:test";
import {PoolClient} from "pg";

import {consumeRegisterClaimGrant, hasValidRegisterClaimGrant,
  issueRegisterClaimResolutionGrant} from "./manager_action_grants";
import {RemoteCommandError, RemoteCommandInput} from "./remote_commands/command_types";

const nonce = "synthetic-approval-nonce-123456789";
const input = {
  managerFirebaseUid: "manager-firebase", organizationId: "org", branchId: "branch",
  conflictId: "conflict", targetRegisterId: "register", deviceId: "device",
  requestedByUserId: "cashier", nonce,
};
const command: RemoteCommandInput = {
  firebaseUid: "cashier-firebase", organizationId: "org", branchId: "branch",
  operationId: "operation", commandType: "register.claim.resolve",
  aggregateType: "register_claim", aggregateId: "conflict", deviceId: "device",
  payload: {managerGrantId: "grant", managerGrantNonce: nonce,
    targetRegisterId: "register"},
};

class FakeClient {
  readonly calls: {sql: string; values?: unknown[]}[] = [];
  constructor(readonly options: {manager?: boolean; binding?: boolean;
    usable?: boolean; insertFails?: boolean} = {}) {}

  async query(sql: string, values?: unknown[]) {
    this.calls.push({sql: sql.replace(/\s+/g, " ").trim(), values});
    let rows: Record<string, unknown>[] = [];
    if (sql.includes("FROM app_users au")) {
      rows = this.options.manager === false ? [] : [{id: "manager"}];
    } else if (sql.includes("FROM register_claims claim")) {
      rows = this.options.binding === false ? [] : [{"?column?": 1}];
    } else if (sql.includes("INSERT INTO manager_action_grants") &&
      this.options.insertFails) {
      throw new Error("insert failed");
    } else if (sql.includes("SELECT 1 FROM manager_action_grants") ||
      sql.includes("UPDATE manager_action_grants")) {
      rows = this.options.usable === false ? [] : [{manager_user_id: "manager"}];
    }
    return {rows, rowCount: rows.length};
  }

  asClient(): PoolClient { return this as unknown as PoolClient; }
}

test("grant issuance serializes access mutations and binds the complete action", async () => {
  const client = new FakeClient();
  const before = Date.now();
  const grant = await issueRegisterClaimResolutionGrant(client.asClient(), input);
  assert.equal(grant.managerUserId, "manager");
  assert.match(String(grant.grantId), /^[a-f0-9-]{36}$/);
  const expires = Date.parse(String(grant.expiresAt));
  assert.ok(expires >= before + 300000 && expires <= Date.now() + 300000);
  assert.equal(client.calls[0].sql, "BEGIN");
  assert.deepEqual(client.calls[1].values, ["access-administration:org"]);
  assert.match(client.calls[1].sql, /pg_advisory_xact_lock/);
  assert.match(client.calls[2].sql, /FOR SHARE OF au, o, b/);
  assert.match(client.calls[2].sql, /b.is_active = true AND b.deleted_at IS NULL/);
  assert.deepEqual(client.calls[2].values, ["manager-firebase", "org", "branch"]);
  assert.match(client.calls[3].sql, /device.disabled_at IS NULL/);
  assert.deepEqual(client.calls[3].values,
    ["conflict", "org", "branch", "register", "device", "cashier"]);
  const values = client.calls[4].values!;
  assert.deepEqual(values.slice(1, 8),
    ["org", "branch", "cashier", "manager", "conflict", "register", "device"]);
  assert.equal(values[8], createHash("sha256").update(nonce).digest("hex"));
  assert.equal(client.calls.at(-1)?.sql, "COMMIT");
});

test("issuance fails closed and rolls back when manager or action binding is invalid", async () => {
  for (const options of [{manager: false}, {binding: false}]) {
    const client = new FakeClient(options);
    await assert.rejects(issueRegisterClaimResolutionGrant(client.asClient(), input),
      (error) => error instanceof RemoteCommandError);
    assert.equal(client.calls.at(-1)?.sql, "ROLLBACK");
    assert.ok(!client.calls.some(({sql}) => sql.includes("INSERT INTO")));
  }
  const client = new FakeClient({insertFails: true});
  await assert.rejects(issueRegisterClaimResolutionGrant(client.asClient(), input),
    /insert failed/);
  assert.equal(client.calls.at(-1)?.sql, "ROLLBACK");
});

test("invalid nonce cannot begin a grant transaction", async () => {
  for (const nonce of ["short", "x".repeat(257)]) {
    const client = new FakeClient();
    await assert.rejects(issueRegisterClaimResolutionGrant(client.asClient(),
      {...input, nonce}), /nonce is invalid/);
    assert.equal(client.calls.length, 0);
  }
});

test("validation and consumption recheck current branch-scoped manager authority", async () => {
  const client = new FakeClient();
  assert.equal(await hasValidRegisterClaimGrant(client.asClient(), command, "cashier"),
    true);
  assert.equal(await consumeRegisterClaimGrant(client.asClient(),
    {...command, actorUserId: "cashier"}), "manager");
  for (const {sql, values} of client.calls) {
    // SQL contract test: both paths must revalidate all revocable authority.
    for (const condition of ["manager.status = 'active'", "manager.deleted_at IS NULL",
      "o.is_active = true", "o.deleted_at IS NULL", "b.is_active = true",
      "b.deleted_at IS NULL", "assignment.revoked_at IS NULL",
      "assignment.branch_id IS NULL OR assignment.branch_id = b.id",
      "role.is_active = true", "role.deleted_at IS NULL",
      "permission.permission_code = 'registers.manage'",
      "manager.id = manager_action_grants.manager_user_id",
      "manager.organization_id = manager_action_grants.organization_id"]) {
      assert.ok(sql.includes(condition), condition);
    }
    assert.deepEqual(values?.slice(0, 7),
      ["grant", "org", "branch", "cashier", "conflict", "register", "device"]);
    assert.equal(values?.[7], createHash("sha256").update(nonce).digest("hex"));
    assert.equal(values?.[8], "operation");
  }
  assert.match(client.calls[0].sql, /OR consumed_by_operation_id = \$9/);
  assert.match(client.calls[1].sql, /AND consumed_at IS NULL AND expires_at > now\(\)/);
});

test("unusable grants cannot authorize or consume and missing evidence skips lookup", async () => {
  const client = new FakeClient({usable: false});
  assert.equal(await hasValidRegisterClaimGrant(client.asClient(), command, "cashier"),
    false);
  await assert.rejects(consumeRegisterClaimGrant(client.asClient(),
    {...command, actorUserId: "cashier"}),
  (error) => error instanceof RemoteCommandError && error.code === "permission-denied");
  const empty = new FakeClient();
  assert.equal(await hasValidRegisterClaimGrant(empty.asClient(),
    {...command, payload: {}}, "cashier"), false);
  assert.equal(empty.calls.length, 0);
});
