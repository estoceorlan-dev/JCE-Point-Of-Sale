"use strict";

// Real, concurrent PostgreSQL tests. Dedicated loopback database only; all test
// tables and fixtures live in a random disposable schema, never a cloud database.
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");
const {Client, Pool} = require("pg");
const {enforceRateLimit, RateLimitExceededError} = require("../lib/api_rate_limiter");
const {enforceUsageAdmission} = require("../lib/usage_admission");
const {loadUsagePolicies} = require("../lib/usage_policy");

async function main() {
  const url = new URL(process.env.JCE_SECURITY_TEST_DATABASE_URL || "invalid:");
  assert.ok(process.argv.includes("--run"));
  assert.ok(["postgres:", "postgresql:"].includes(url.protocol));
  assert.ok(["127.0.0.1", "localhost", "[::1]"].includes(url.hostname));
  assert.equal(url.pathname, "/jce_security_test");
  assert.equal(url.search, "");
  const schema = `usage_test_${randomUUID().replaceAll("-", "")}`;
  const options = {connectionString: url.href, connectionTimeoutMillis: 5000,
    statement_timeout: 10000};
  const owner = new Client(options);
  const pool = new Pool({...options, max: 5, options: `-c search_path=${schema},pg_catalog`});
  let created = false;
  let passed = 0;
  async function withClient(action) {
    const client = await pool.connect();
    try {return await action(client);} finally {client.release();}
  }
  const started = Date.now();
  try {
    await owner.connect();
    await owner.query(`CREATE SCHEMA ${schema}`);
    created = true;
    await owner.query(`SET search_path = ${schema}, pg_catalog`);
    const directory = path.resolve(__dirname, "../../sql/migrations");
    for (const migration of (await fs.readdir(directory))
      .filter((name) => /^\d{4}_.*\.sql$/.test(name)).sort()) {
      await owner.query(await fs.readFile(path.join(directory, migration), "utf8"));
    }
    const input = {firebaseUid: "synthetic-user", scope: "concurrency", maximumRequests: 25,
      windowSeconds: 86400};
    const outcomes = await Promise.all(Array.from({length: 100}, () => withClient(async (client) => {
      try {await enforceRateLimit(client, input); return "accepted";}
      catch (error) {assert.ok(error instanceof RateLimitExceededError);
        assert.ok(error.retryAfterSeconds >= 1 && error.retryAfterSeconds <= 86400);
        return "denied";}
    })));
    assert.equal(outcomes.filter((outcome) => outcome === "accepted").length, 25);
    const counter = await owner.query("SELECT request_count FROM api_rate_limit_windows WHERE scope = 'concurrency'");
    assert.equal(counter.rows[0].request_count, 26); // saturates, cannot overflow
    passed++;
    await Promise.all(Array.from({length: 100}, () => withClient((client) =>
      enforceRateLimit(client, {...input, scope: "ordinary", maximumRequests: 120}))));
    passed++;
    await owner.query("UPDATE api_rate_limit_windows SET window_started_at = window_started_at - interval '2 days', expires_at = expires_at - interval '2 days' WHERE scope = 'concurrency'");
    await withClient((client) => enforceRateLimit(client, input));
    passed++;
    const bytes = {...input, scope: "bytes", maximumRequests: 100, units: 30};
    for (let index = 0; index < 3; index++) await withClient((client) => enforceRateLimit(client, bytes));
    await assert.rejects(withClient((client) => enforceRateLimit(client, bytes)), RateLimitExceededError);
    passed++;
    await owner.query(`
      INSERT INTO organizations (id, code, name) VALUES ('org', 'TEST', 'Synthetic');
      INSERT INTO app_users (id, organization_id, firebase_uid, email, display_name, status)
        VALUES ('a', 'org', 'a', 'a@example.invalid', 'Synthetic', 'active'),
          ('b', 'org', 'b', 'b@example.invalid', 'Synthetic', 'active');
      INSERT INTO roles (id, organization_id, code, name) VALUES ('role', 'org', 'TEST', 'Synthetic');
      INSERT INTO user_role_assignments (id, organization_id, user_id, role_id)
        VALUES ('a-role', 'org', 'a', 'role'), ('b-role', 'org', 'b', 'role');
    `);
    const policy = {...loadUsagePolicies("{}").product_image,
      organization: {maximumRequests: 3, windowSeconds: 86400}};
    const call = (firebaseUid, organizationId = "org") => withClient((client) =>
      enforceUsageAdmission(client, {firebaseUid, organizationId, scope: "product_image", policy}));
    for (let index = 0; index < 10; index++) await call("outsider");
    for (let index = 0; index < 3; index++) await call(index % 2 ? "a" : "b");
    await assert.rejects(call("a"), RateLimitExceededError);
    passed++;
    await call("a", "foreign-org"); // cannot charge foreign shared quota
    passed++;
    console.log(JSON.stringify({passed, concurrentRequests: 100, connections: 5,
      elapsedMs: Date.now() - started, fixture: "synthetic-local-only"}));
  } finally {
    await pool.end();
    if (created) {await owner.query(`DROP SCHEMA ${schema} CASCADE`);
      console.log("Synthetic usage-test schema removed.");}
    await owner.end();
  }
}
main().catch((error) => {console.error(`${error.code || error.name}: ${error.message}`);
  process.exitCode = 1;});
