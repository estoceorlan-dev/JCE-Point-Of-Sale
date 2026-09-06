// Operator-only, explicitly approved initial permission grant. Not a callable.
const {Connector} = require("@google-cloud/cloud-sql-connector");
const {Client} = require("pg");
const {randomUUID} = require("node:crypto");
const {signInStaging} = require("./staging-auth-session");
const permissionCodes = ["branches.manage", "roles.manage"];

async function main() {
  const project = process.env.JCE_STAGING_PROJECT;
  const instance = process.env.JCE_DB_INSTANCE_CONNECTION_NAME;
  const organizationId = process.env.JCE_ACCESS_ORGANIZATION_ID;
  const roleId = process.env.JCE_ACCESS_ROLE_ID;
  const operationId = process.env.JCE_ACCESS_OPERATION_ID;
  const migrationRole = process.env.JCE_DB_MIGRATION_ROLE;
  if (!project?.includes("staging") || instance?.split(":")[0] !== project ||
      !organizationId || !roleId || !operationId || !/^[a-z_][a-z0-9_]*$/.test(migrationRole || "")) {
    throw new Error("Explicit staging connection, organization/role/operation IDs and migration role required.");
  }
  const session = await signInStaging("Administrator");
  const connector = new Connector(); let client;
  try {
    const options = await connector.getOptions({instanceConnectionName: instance, authType: "IAM", ipType: "PUBLIC"});
    client = new Client({...options, user: process.env.JCE_DB_USER, database: process.env.JCE_DB_NAME,
      connectionTimeoutMillis: 15000, statement_timeout: 15000});
    await client.connect(); await client.query("BEGIN");
    await client.query(`SET LOCAL ROLE ${migrationRole}`);
    await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [`access-administration:${organizationId}`]);
    const actor = await client.query(`SELECT u.id FROM app_users u
      JOIN organizations o ON o.id=u.organization_id AND o.is_active AND o.deleted_at IS NULL
      JOIN user_role_assignments a ON a.user_id=u.id AND a.organization_id=u.organization_id
      JOIN roles r ON r.id=a.role_id AND r.organization_id=u.organization_id
      JOIN role_permissions p ON p.role_id=r.id AND p.permission_code='users.manage'
      WHERE u.organization_id=$1 AND u.firebase_uid=$2 AND u.status='active' AND u.deleted_at IS NULL
        AND a.role_id=$3 AND a.branch_id IS NULL AND a.revoked_at IS NULL
        AND r.is_active AND r.deleted_at IS NULL`, [organizationId, session.uid, roleId]);
    if (!actor.rowCount) throw new Error("Signed-in administrator does not hold the approved organization-wide role.");
    const prior = await client.query("SELECT 1 FROM audit_logs WHERE organization_id=$1 AND operation_id=$2 AND action='role.permissions.provision' AND entity_id=$3", [organizationId, operationId, roleId]);
    if (prior.rowCount) { await client.query("ROLLBACK"); console.log(JSON.stringify({duplicate: true, roleId})); return; }
    const role = await client.query("SELECT * FROM roles WHERE id=$1 AND organization_id=$2 FOR UPDATE", [roleId, organizationId]);
    const before = (await client.query("SELECT permission_code FROM role_permissions WHERE role_id=$1 ORDER BY permission_code", [roleId])).rows.map((r) => r.permission_code);
    const missing = permissionCodes.filter((code) => !before.includes(code));
    if (!process.argv.includes("--apply") || !missing.length) {
      await client.query("ROLLBACK"); console.log(JSON.stringify({roleId, missing, applied: false})); return;
    }
    for (const code of missing) await client.query("INSERT INTO role_permissions (role_id,permission_code) VALUES ($1,$2) ON CONFLICT DO NOTHING", [roleId, code]);
    const updated = (await client.query(`UPDATE roles SET version=version+1,updated_at=now()
      WHERE id=$1 AND organization_id=$2 RETURNING id,organization_id AS "organizationId",code,name,description,
      is_active AS "isActive",version,created_at AS "createdAt",updated_at AS "updatedAt",deleted_at AS "deletedAt"`, [roleId, organizationId])).rows[0];
    const permissions = [...new Set([...before, ...missing])].sort();
    const result = {role: {...updated, permissions}};
    const operator = (await client.query("SELECT session_user AS name")).rows[0].name;
    await client.query(`INSERT INTO audit_logs (id,organization_id,actor_user_id,firebase_uid,operation_id,
      action,entity_type,entity_id,metadata_json) VALUES ($1,$2,$3,$4,$5,'role.permissions.provision','role',$6,$7)`,
    [randomUUID(), organizationId, actor.rows[0].id, session.uid, operationId, roleId,
      {operatorDatabaseUser: operator, provisioning: true, approvedPermissionCodes: permissionCodes, previousPermissions: before, permissions}]);
    await client.query(`INSERT INTO change_feed (organization_id,branch_id,aggregate_type,aggregate_id,
      operation_id,change_type,version,payload_json) VALUES ($1,NULL,'role',$2,$3,'upsert',$4,$5)`,
    [organizationId, roleId, operationId, updated.version, {schemaVersion: 1, commandType: "role.update",
      actorUserId: actor.rows[0].id, commandPayload: {id: roleId, expectedVersion: role.rows[0].version,
        code: updated.code, name: updated.name, description: updated.description, permissions}, result}]);
    await client.query("COMMIT");
    console.log(JSON.stringify({organizationId, roleId, added: missing, version: updated.version, audited: true, feedPublished: true}));
  } finally {
    if (client) { await client.query("ROLLBACK").catch(() => {}); await client.end(); }
    connector.close();
  }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
