// Regression rehearsal for the isolated local restore, never a live rollout.
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");

async function verifyAdministrationMigration(client) {
  const sql = await fs.readFile(path.resolve(__dirname,
    "../../sql/migrations/0011_admin_operations.sql"), "utf8");
  await client.query("BEGIN");
  try {
    const organizationId = randomUUID();
    await client.query("INSERT INTO organizations (id, code, name) VALUES ($1, $1, 'Migration fixture')", [organizationId]);
    // Adversarial fixture names: the old migration silently elevated these.
    for (const code of ["owner", "admin", "ADMIN", "custom-operations"]) {
      const roleId = randomUUID();
      await client.query("INSERT INTO roles (id, organization_id, code, name) VALUES ($1, $2, $3, $3)",
        [roleId, organizationId, code]);
      await client.query("INSERT INTO role_permissions (role_id, permission_code) VALUES ($1, 'users.manage')", [roleId]);
    }
    const grantsSql = "SELECT role_id, permission_code, granted_at FROM role_permissions ORDER BY role_id, permission_code";
    const before = (await client.query(grantsSql)).rows;
    await client.query(sql);
    assert.deepEqual((await client.query(grantsSql)).rows, before,
      "Administration migration must preserve every existing grant and grant timestamp.");
    const permissions = await client.query("SELECT code FROM permissions WHERE code = ANY($1::text[]) ORDER BY code",
      [["branches.manage", "roles.manage"]]);
    assert.deepEqual(permissions.rows.map((row) => row.code), ["branches.manage", "roles.manage"]);
    await client.query(sql);
    assert.deepEqual((await client.query(grantsSql)).rows, before,
      "Replaying the migration must not change role grants.");
  } finally {
    await client.query("ROLLBACK");
  }
}

module.exports = {verifyAdministrationMigration};
