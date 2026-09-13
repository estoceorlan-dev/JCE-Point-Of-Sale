// Read-only verification for the Windows-first POS synchronization rollout.
// Credentials and access tokens are supplied by the operator environment and
// are never printed.
const {Connector} = require("@google-cloud/cloud-sql-connector");
const {Client} = require("pg");

function requiredEnvironmentValue(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

async function main() {
  const instanceConnectionName = requiredEnvironmentValue(
    "JCE_DB_INSTANCE_CONNECTION_NAME",
  );
  if (!instanceConnectionName.split(":")[0].includes("staging")) {
    throw new Error("An explicit staging instance is required.");
  }
  const database = requiredEnvironmentValue("JCE_DB_NAME");
  const runtimeUser = requiredEnvironmentValue("JCE_DB_USER");
  const operatorUser = requiredEnvironmentValue("JCE_DB_OPERATOR_USER");
  const connector = new Connector();
  let client;
  try {
    const options = await connector.getOptions({
      instanceConnectionName,
      authType: "IAM",
      ipType: "PUBLIC",
    });
    client = new Client({
      ...options,
      database,
      user: operatorUser,
      connectionTimeoutMillis: 15000,
      statement_timeout: 15000,
    });
    await client.connect();
    await client.query("BEGIN READ ONLY");
    const migration = await client.query(
      "SELECT name FROM schema_migrations WHERE name = $1",
      ["0014_pos_sync_v2.sql"],
    );
    const tables = [
      "register_claims",
      "manager_action_grants",
      "sale_receipt_aliases",
    ];
    const privileges = await client.query(
      `SELECT table_name,
         has_table_privilege(
           $1,
           quote_ident(table_schema) || chr(46) || quote_ident(table_name),
           $2
         ) AS usable
       FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name = ANY($3::text[])
       ORDER BY table_name`,
      [runtimeUser, "SELECT,INSERT,UPDATE", tables],
    );
    const indexes = await client.query(
      `SELECT indexname FROM pg_indexes
       WHERE schemaname = 'public' AND indexname = ANY($1::text[])
       ORDER BY indexname`,
      [[
        "register_claims_active_device_uidx",
        "register_claims_active_register_uidx",
        "sale_receipt_aliases_canonical_idx",
      ]],
    );
    const permission = await client.query(
      `SELECT count(*)::integer AS permission_count,
         (SELECT count(*)::integer FROM role_permissions
          WHERE permission_code = 'registers.claim') AS role_grant_count
       FROM permissions WHERE code = 'registers.claim'`,
    );
    const duplicates = await client.query(
      `SELECT
         (SELECT count(*)::integer FROM (
           SELECT organization_id, device_id FROM register_claims
           WHERE status IN ('accepted', 'resolved')
           GROUP BY organization_id, device_id HAVING count(*) > 1
         ) duplicate_devices) AS duplicate_devices,
         (SELECT count(*)::integer FROM (
           SELECT organization_id,
             COALESCE(resolved_register_id, requested_register_id)
           FROM register_claims WHERE status IN ('accepted', 'resolved')
           GROUP BY organization_id,
             COALESCE(resolved_register_id, requested_register_id)
           HAVING count(*) > 1
         ) duplicate_registers) AS duplicate_registers`,
    );
    await client.query("COMMIT");

    const result = {
      migrationApplied: migration.rowCount === 1,
      runtimePrivileges: privileges.rows,
      indexes: indexes.rows.map((row) => row.indexname),
      permission: permission.rows[0],
      activeClaimDuplicates: duplicates.rows[0],
      businessWrites: 0,
    };
    console.log(JSON.stringify(result, null, 2));
    if (!result.migrationApplied ||
        privileges.rows.length !== tables.length ||
        privileges.rows.some((row) => !row.usable) ||
        indexes.rowCount !== 3 ||
        result.permission.permission_count !== 1 ||
        result.activeClaimDuplicates.duplicate_devices !== 0 ||
        result.activeClaimDuplicates.duplicate_registers !== 0) {
      process.exitCode = 1;
    }
  } finally {
    if (client) await client.end();
    connector.close();
  }
}

main().catch((error) => {
  console.error(JSON.stringify({code: error.code, message: error.message}));
  process.exitCode = 1;
});
