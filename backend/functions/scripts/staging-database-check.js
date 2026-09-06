const {Connector} = require("@google-cloud/cloud-sql-connector");
const {Client} = require("pg");
const fs = require("node:fs/promises");
const path = require("node:path");
const crypto = require("node:crypto");

async function main() {
  const instanceConnectionName = process.env.JCE_DB_INSTANCE_CONNECTION_NAME;
  if (!instanceConnectionName?.split(":")[0].includes("staging")) {
    throw new Error("An explicit staging instance is required.");
  }
  if (!process.env.JCE_DB_USER || !process.env.JCE_DB_NAME) {
    throw new Error("JCE_DB_USER and JCE_DB_NAME are required.");
  }
  const connector = new Connector();
  let client;
  try {
    const options = await connector.getOptions({instanceConnectionName, authType: "IAM", ipType: "PUBLIC"});
    client = new Client({...options, user: process.env.JCE_DB_USER,
      database: process.env.JCE_DB_NAME, connectionTimeoutMillis: 15000,
      statement_timeout: 15000});
    await client.connect();
    await client.query("BEGIN READ ONLY");
    const migrations = await client.query("SELECT name, checksum FROM schema_migrations ORDER BY name");
    const directory = path.resolve(__dirname, "../../sql/migrations");
    const names = (await fs.readdir(directory)).filter((name) => /^\d{4}_.*\.sql$/.test(name)).sort();
    const checks = [];
    for (const name of names) {
      const checksum = crypto.createHash("sha256").update(await fs.readFile(path.join(directory, name))).digest("hex");
      const applied = migrations.rows.find((row) => row.name === name);
      checks.push({name, status: !applied ? "pending" : applied.checksum === checksum ? "matched" : "CHECKSUM_MISMATCH"});
    }
    const duplicates = await client.query(`SELECT count(*) AS groups FROM (
      SELECT organization_id, upper(btrim(code)) FROM branches
      GROUP BY organization_id, upper(btrim(code)) HAVING count(*) > 1) duplicates`);
    const owner = await client.query("SELECT current_user, pg_has_role(current_user, 'jce_pos_migrator', 'MEMBER') AS can_migrate");
    const ownership = await client.query(`SELECT tableowner, count(*) AS tables
      FROM pg_tables WHERE schemaname = 'public' GROUP BY tableowner`);
    const permissions = await client.query(`SELECT
      has_table_privilege(current_user, 'branches', 'UPDATE') AS can_lock_branch,
      has_schema_privilege(current_user, 'public', 'CREATE') AS can_create_schema_objects`);
    await client.query("COMMIT");
    console.log(JSON.stringify({checks, duplicateCodeGroups: duplicates.rows[0].groups,
      migrationAccess: owner.rows[0], ownership: ownership.rows,
      privileges: permissions.rows[0]}, null, 2));
    if (checks.some((check) => check.status === "CHECKSUM_MISMATCH")) process.exitCode = 1;
    if (process.argv.includes("--check-locks")) {
      const peer = new Client({...options, user: process.env.JCE_DB_USER,
        database: process.env.JCE_DB_NAME, connectionTimeoutMillis: 15000,
        statement_timeout: 5000});
      try {
        await peer.connect();
        const sample = await client.query("SELECT id FROM branches WHERE is_active = true AND deleted_at IS NULL ORDER BY id LIMIT 1");
        if (!sample.rows.length) throw new Error("No active staging branch is available for lock checks.");
        const id = sample.rows[0].id;
        await client.query("BEGIN");
        await client.query("SELECT id FROM branches WHERE id = $1 FOR SHARE", [id]);
        await peer.query("BEGIN");
        await peer.query("SET LOCAL lock_timeout = '500ms'");
        let blocked = false;
        try {
          await peer.query("SELECT id FROM branches WHERE id = $1 FOR UPDATE", [id]);
        } catch (error) {
          if (error.code !== "55P03") throw error;
          blocked = true;
        }
        await peer.query("ROLLBACK");
        await client.query("ROLLBACK");
        if (!blocked) throw new Error("Exclusive archival lock unexpectedly bypassed shared operation lock.");
        await peer.query("BEGIN");
        await peer.query("SET LOCAL lock_timeout = '500ms'");
        await peer.query("SELECT id FROM branches WHERE id = $1 FOR UPDATE", [id]);
        await peer.query("ROLLBACK");
        const key = `staging-validation:${crypto.randomUUID()}`;
        await client.query("BEGIN");
        await peer.query("BEGIN");
        await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [key]);
        const competing = await peer.query("SELECT pg_try_advisory_xact_lock(hashtextextended($1, 0)) AS acquired", [key]);
        if (competing.rows[0].acquired) throw new Error("Advisory serialization failed.");
        await client.query("ROLLBACK");
        const released = await peer.query("SELECT pg_try_advisory_xact_lock(hashtextextended($1, 0)) AS acquired", [key]);
        if (!released.rows[0].acquired) throw new Error("Advisory lock did not release after rollback.");
        await peer.query("ROLLBACK");
        console.log(JSON.stringify({lockChecks: "passed", businessWrites: 0,
          scope: "shared/exclusive branch row locks and transaction advisory locks; not full command concurrency"}));
      } finally {
        await client.query("ROLLBACK").catch(() => {});
        await peer.query("ROLLBACK").catch(() => {});
        await peer.end();
      }
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
