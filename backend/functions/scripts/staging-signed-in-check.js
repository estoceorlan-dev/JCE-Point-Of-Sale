// Explicit staging-only probes. Creates a labelled QA branch, staff and role;
// archives/disables them in finally, preserves history and never creates sales.
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const {Connector} = require("@google-cloud/cloud-sql-connector");
const {Client} = require("pg");
const {signInStaging, callStaging} = require("./staging-auth-session");
const {createStagingCashier} = require("./staging-cashier-fixture");

async function main() {
  if (!process.argv.includes("--run")) throw new Error("--run explicitly enables staging fixture writes.");
  const organizationId = process.env.JCE_ACCESS_ORGANIZATION_ID;
  const instance = process.env.JCE_DB_INSTANCE_CONNECTION_NAME;
  if (!organizationId || instance?.split(":")[0] !== process.env.JCE_STAGING_PROJECT) throw new Error("Explicit matching staging organization/database required.");
  const [admin, peer] = await Promise.all([
    signInStaging("Administrator"), signInStaging("Administrator"),
  ]);
  const pass = (name) => console.log(JSON.stringify({check: name, passed: true}));
  const okay = (response) => {
    assert.equal(response.httpStatus, 200, `Callable failed: ${response.error?.status || response.httpStatus}`);
    assert.ok(!response.error); return response.result;
  };
  const denied = (response, code = "PERMISSION_DENIED") => {
    assert.equal(response.error?.status, code); assert.notEqual(response.httpStatus, 200);
  };
  const profile = okay(await callStaging(admin, "getMyAccessProfile", {}));
  const membership = profile.organizations.find((item) => item.organization.id === organizationId);
  assert.ok(membership);
  assert.ok(membership.branches.length);
  const branchId = membership.branches[0].branch.id;
  for (const code of ["branches.manage", "roles.manage"]) {
    assert.ok(membership.organizationRoles.some((role) => role.permissions.includes(code)));
  }
  pass("signed-in admin profile and approved administration grants");
  const connector = new Connector(); let client, cashierFixture;
  const fixtureId = randomUUID(); const createOperationId = randomUUID();
  const code = `QA-${fixtureId.slice(0, 8).toUpperCase()}`;
  const draft = {id: fixtureId, code, name: `QA concurrency ${code}`, timezone: "Asia/Manila", receiptDisplayName: "QA ONLY"};
  const command = (type, payload, overrides = {}) => ({operationId: randomUUID(), organizationId,
    branchId, commandType: type, aggregateType: "branch", aggregateId: fixtureId, payload, ...overrides});
  const send = (session, input) => callStaging(session, "applyRemoteCommand", input);
  try {
    cashierFixture = await createStagingCashier(admin, organizationId, branchId);
    const cashier = cashierFixture.session;
    const snapshots = await Promise.all([admin, peer, admin, peer].map((session) => callStaging(session, "getAdministrationSnapshot", {organizationId})));
    snapshots.forEach(okay);
    denied(await callStaging(cashier, "getAdministrationSnapshot", {organizationId}));
    pass("concurrent administration snapshots and cashier snapshot rejection");
    const options = await connector.getOptions({instanceConnectionName: instance, authType: "IAM", ipType: "PUBLIC"});
    client = new Client({...options, user: process.env.JCE_DB_USER, database: process.env.JCE_DB_NAME,
      connectionTimeoutMillis: 15000, statement_timeout: 15000});
    await client.connect();
    const create = command("branch.create", draft, {operationId: createOperationId});
    const creations = await Promise.all([admin, peer, admin, peer].map((session) => send(session, create)));
    const results = creations.map(okay);
    assert.equal(results.filter((result) => !result.duplicate).length, 1);
    assert.equal(results.filter((result) => result.duplicate).length, 3);
    const counts = (await client.query(`SELECT
      (SELECT count(*)::int FROM branches WHERE id=$1 AND organization_id=$2) AS branches,
      (SELECT count(*)::int FROM audit_logs WHERE organization_id=$2 AND operation_id=$3) AS audits,
      (SELECT count(*)::int FROM change_feed WHERE organization_id=$2 AND operation_id=$3) AS changes,
      (SELECT count(*)::int FROM processed_operations WHERE organization_id=$2 AND operation_id=$3) AS operations`,
    [fixtureId, organizationId, createOperationId])).rows[0];
    assert.deepEqual(counts, {branches: 1, audits: 1, changes: 1, operations: 1});
    pass("four identical concurrent commands produce one branch/audit/feed/operation");
    const edits = await Promise.all([admin, peer].map((session, index) => send(session,
      command("branch.update", {...draft, name: `${draft.name} edit ${index}`, expectedVersion: 0}))));
    assert.equal(edits.filter((response) => response.httpStatus === 200).length, 1);
    denied(edits.find((response) => response.httpStatus !== 200), "ABORTED");
    assert.equal((await client.query("SELECT version FROM branches WHERE id=$1", [fixtureId])).rows[0].version, 1);
    pass("competing version-zero edits commit once and reject the stale writer");
    denied(await send(cashier, command("branch.update", {...draft, expectedVersion: 1})));
    denied(await send(cashier, command("branch.update_name", {name: draft.name}, {branchId: fixtureId})));
    denied(await send(admin, command("branch.update", {...draft, expectedVersion: 1}, {organizationId: randomUUID()})));
    pass("cashier administration/cross-branch and unknown-organization rejection");
    denied(await send(admin, command("branch.archive", {expectedVersion: 1}, {branchId: fixtureId})), "FAILED_PRECONDITION");
    const archived = okay(await send(admin, command("branch.archive", {expectedVersion: 1})));
    assert.equal(archived.result.branch.isActive, false);
    denied(await send(admin, command("branch.update", {...draft, expectedVersion: 2})), "ABORTED");
    const restored = okay(await send(admin, command("branch.restore", {expectedVersion: 2})));
    assert.equal(restored.result.branch.isActive, true);
    pass("current-branch archive guard, archive/edit rejection and restore");
    console.log(JSON.stringify({fixtureBranchId: fixtureId, fixtureCode: code,
      scope: "branch concurrency, role isolation and invite happy path/replay; not shift/count/transfer races, invite negative cases or hardware acceptance"}));
  } finally {
    const cleanupErrors = [];
    if (client) {
      try {
        const row = (await client.query("SELECT version,is_active FROM branches WHERE id=$1 AND organization_id=$2", [fixtureId, organizationId])).rows[0];
        if (row?.is_active) okay(await send(admin, command("branch.archive", {expectedVersion: row.version})));
        console.log(JSON.stringify({fixtureBranchId: fixtureId, cleanup: row ? "archived; audit/history retained" : "not created"}));
      } catch (error) { cleanupErrors.push(error); }
      finally { await client.end(); }
    }
    connector.close();
    if (cashierFixture) {
      try { await cashierFixture.cleanup(); } catch (error) { cleanupErrors.push(error); }
    }
    if (cleanupErrors.length) throw new Error(`Fixture cleanup incomplete: ${cleanupErrors.map((error) => error.message).join("; ")}`);
  }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
