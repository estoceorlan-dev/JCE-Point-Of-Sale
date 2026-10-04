"use strict";

// Real PostgreSQL regression test. Loopback + a dedicated test database are
// mandatory. The randomly named schema contains synthetic fixtures only and is
// removed afterwards; this script cannot target Cloud SQL or a business database.
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");
const {Client} = require("pg");
const {issueRegisterClaimResolutionGrant, hasValidRegisterClaimGrant,
  consumeRegisterClaimGrant} = require("../lib/manager_action_grants");

async function main() {
  const url = new URL(process.env.JCE_SECURITY_TEST_DATABASE_URL || "invalid:");
  assert.ok(process.argv.includes("--run"), "--run is required");
  assert.ok(["postgres:", "postgresql:"].includes(url.protocol));
  assert.ok(["127.0.0.1", "localhost", "[::1]"].includes(url.hostname),
    "Only a local PostgreSQL server is allowed");
  assert.equal(url.pathname, "/jce_security_test");
  assert.equal(url.search, "", "Connection URL query overrides are prohibited");
  const options = {connectionString: url.href, connectionTimeoutMillis: 5000,
    statement_timeout: 10000};
  const client = new Client(options);
  const peer = new Client(options);
  const schema = `grant_test_${randomUUID().replaceAll("-", "")}`;
  let schemaCreated = false;
  let checks = 0;
  try {
    await client.connect();
    await peer.connect();
    await client.query(`CREATE SCHEMA ${schema}`);
    schemaCreated = true;
    for (const connection of [client, peer]) {
      await connection.query(`SET search_path = ${schema}, pg_catalog`);
    }
    const directory = path.resolve(__dirname, "../../sql/migrations");
    const migrations = (await fs.readdir(directory))
      .filter((name) => /^\d{4}_.*\.sql$/.test(name)).sort();
    for (const migration of migrations) {
      await client.query(await fs.readFile(path.join(directory, migration), "utf8"));
    }
    await client.query(`
      INSERT INTO organizations (id, code, name) VALUES ('org', 'TEST', 'Synthetic');
      INSERT INTO branches (id, organization_id, code, name)
        VALUES ('branch', 'org', 'ONE', 'Test'), ('other-branch', 'org', 'TWO', 'Test');
      INSERT INTO app_users (id, organization_id, firebase_uid, email, display_name, status)
        VALUES ('manager', 'org', 'manager-firebase', 'manager@example.invalid', 'Test', 'active'),
          ('cashier', 'org', 'cashier-firebase', 'cashier@example.invalid', 'Test', 'active'),
          ('other-cashier', 'org', 'other-firebase', 'other@example.invalid', 'Test', 'active');
      INSERT INTO roles (id, organization_id, code, name) VALUES ('role', 'org', 'TEST', 'Test');
      INSERT INTO permissions (code, name) VALUES ('registers.manage', 'Manage registers')
        ON CONFLICT DO NOTHING;
      INSERT INTO role_permissions (role_id, permission_code) VALUES ('role', 'registers.manage');
      INSERT INTO user_role_assignments (id, organization_id, branch_id, user_id, role_id)
        VALUES ('assignment', 'org', 'branch', 'manager', 'role');
      INSERT INTO devices (id, organization_id, branch_id, platform)
        VALUES ('device', 'org', 'branch', 'android');
      INSERT INTO registers (id, organization_id, branch_id, code, name)
        VALUES ('original', 'org', 'branch', 'ONE', 'Test'),
          ('target', 'org', 'branch', 'TWO', 'Test');
      INSERT INTO register_claims (id, organization_id, branch_id, requested_register_id,
        device_id, claimed_by_user_id, status)
        VALUES ('conflict', 'org', 'branch', 'original', 'device', 'other-cashier', 'rejected');
    `);
    const input = {managerFirebaseUid: "manager-firebase", organizationId: "org",
      branchId: "branch", conflictId: "conflict", targetRegisterId: "target",
      deviceId: "device", requestedByUserId: "cashier", nonce: randomUUID()};
    const grant = await issueRegisterClaimResolutionGrant(client, input);
    const command = {firebaseUid: "cashier-firebase", operationId: "operation",
      organizationId: "org", branchId: "branch", deviceId: "device",
      aggregateId: "conflict", aggregateType: "register_claim",
      commandType: "register.claim.resolve", actorUserId: "cashier",
      payload: {managerGrantId: grant.grantId, managerGrantNonce: input.nonce,
        targetRegisterId: "target"}};
    assert.equal(await hasValidRegisterClaimGrant(client, command, "cashier"), true);
    checks++;
    const revocations = [
      ["UPDATE app_users SET status = 'disabled' WHERE id = 'manager'",
        "UPDATE app_users SET status = 'active' WHERE id = 'manager'"],
      ["UPDATE app_users SET deleted_at = now() WHERE id = 'manager'",
        "UPDATE app_users SET deleted_at = NULL WHERE id = 'manager'"],
      ["UPDATE organizations SET is_active = false", "UPDATE organizations SET is_active = true"],
      ["UPDATE organizations SET deleted_at = now()", "UPDATE organizations SET deleted_at = NULL"],
      ["UPDATE branches SET is_active = false", "UPDATE branches SET is_active = true"],
      ["UPDATE branches SET deleted_at = now()", "UPDATE branches SET deleted_at = NULL"],
      ["UPDATE roles SET is_active = false", "UPDATE roles SET is_active = true"],
      ["UPDATE roles SET deleted_at = now()", "UPDATE roles SET deleted_at = NULL"],
      ["UPDATE user_role_assignments SET revoked_at = now()",
        "UPDATE user_role_assignments SET revoked_at = NULL"],
      ["UPDATE user_role_assignments SET branch_id = 'other-branch'",
        "UPDATE user_role_assignments SET branch_id = 'branch'"],
      ["DELETE FROM role_permissions WHERE permission_code = 'registers.manage'",
        "INSERT INTO role_permissions (role_id, permission_code) VALUES ('role', 'registers.manage')"],
      ["UPDATE manager_action_grants SET expires_at = now() - interval '1 second'",
        "UPDATE manager_action_grants SET expires_at = now() + interval '5 minutes'"],
    ];
    for (const [revoke, restore] of revocations) {
      await client.query(revoke);
      assert.equal(await hasValidRegisterClaimGrant(client, command, "cashier"), false, revoke);
      await assert.rejects(consumeRegisterClaimGrant(client, command),
        (error) => error.code === "permission-denied", revoke);
      await client.query(restore);
      assert.equal(await hasValidRegisterClaimGrant(client, command, "cashier"), true);
      checks++;
    }
    for (const changed of [
      {...command, organizationId: "foreign"}, {...command, branchId: "other-branch"},
      {...command, deviceId: "foreign"}, {...command, aggregateId: "foreign"},
      {...command, actorUserId: "other-cashier"},
      {...command, payload: {...command.payload, managerGrantNonce: randomUUID()}},
      {...command, payload: {...command.payload, targetRegisterId: "original"}},
    ]) {
      assert.equal(await hasValidRegisterClaimGrant(client, changed, changed.actorUserId), false);
      await assert.rejects(consumeRegisterClaimGrant(client, changed),
        (error) => error.code === "permission-denied");
      checks++;
    }
    assert.equal(await consumeRegisterClaimGrant(client, command), "manager");
    await assert.rejects(consumeRegisterClaimGrant(client, command),
      (error) => error.code === "permission-denied");
    assert.equal(await hasValidRegisterClaimGrant(client, command, "cashier"), true);
    assert.equal(await hasValidRegisterClaimGrant(client,
      {...command, operationId: "different-operation"}, "cashier"), false);
    checks++;

    // A role revocation holding the same advisory lock must finish before
    // approval issuance can examine permissions. No arbitrary sleep is needed.
    await peer.query("BEGIN");
    await peer.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      ["access-administration:org"]);
    await client.query("SET lock_timeout = '250ms'");
    await assert.rejects(issueRegisterClaimResolutionGrant(client,
      {...input, nonce: randomUUID()}), (error) => error.code === "55P03");
    await peer.query("UPDATE user_role_assignments SET revoked_at = now()");
    await peer.query("COMMIT");
    await assert.rejects(issueRegisterClaimResolutionGrant(client,
      {...input, nonce: randomUUID()}), (error) => error.code === "permission-denied");
    checks++;
    console.log(JSON.stringify({passed: checks, migrations: migrations.length,
      fixture: "synthetic-local-only"}));
  } finally {
    await peer.query("ROLLBACK").catch(() => {});
    await peer.end().catch(() => {});
    if (schemaCreated) {
      await client.query("ROLLBACK");
      await client.query(`DROP SCHEMA ${schema} CASCADE`);
      console.log("Synthetic test schema removed.");
    }
    await client.end();
  }
}

main().catch((error) => {
  console.error(`${error.code || error.name}: ${error.message}`);
  process.exitCode = 1;
});
