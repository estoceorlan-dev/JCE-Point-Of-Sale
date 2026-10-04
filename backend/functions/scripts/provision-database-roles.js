const {Connector} = require("@google-cloud/cloud-sql-connector");
const {Client} = require("pg");

function requiredEnvironmentValue(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

function validatedRole(name, fallback) {
  const value = process.env[name]?.trim() || fallback;
  if (!/^[a-z_][a-z0-9_]{0,62}$/.test(value)) {
    throw new Error(`${name} is invalid.`);
  }
  return value;
}

function validatedPrincipal(name) {
  const value = requiredEnvironmentValue(name);
  if (!/^[a-zA-Z0-9._@-]{1,63}$/.test(value)) {
    throw new Error(`${name} is invalid.`);
  }
  return value;
}

function quoteIdentifier(value) {
  return `"${value.replaceAll('"', '""')}"`;
}

async function ensureRole(client, role, attributes) {
  const existing = await client.query(
    "SELECT 1 FROM pg_roles WHERE rolname = $1",
    [role],
  );
  if (existing.rowCount === 0) {
    await client.query(
      `CREATE ROLE ${quoteIdentifier(role)} ${attributes}`,
    );
  }
}

async function main() {
  const instanceConnectionName = requiredEnvironmentValue(
    "JCE_DB_INSTANCE_CONNECTION_NAME",
  );
  const database = requiredEnvironmentValue("JCE_DB_NAME");
  const adminPassword = requiredEnvironmentValue("JCE_DB_ADMIN_PASSWORD");
  const migrationPrincipal = validatedPrincipal("JCE_DB_MIGRATION_PRINCIPAL");
  const runtimePrincipal = validatedPrincipal("JCE_DB_RUNTIME_PRINCIPAL");
  const migrationRole = validatedRole(
    "JCE_DB_MIGRATION_ROLE",
    "jce_pos_migration_owner",
  );
  const runtimeRole = validatedRole("JCE_DB_RUNTIME_ROLE", "jce_pos_runtime");
  const phase = process.env.JCE_DB_SETUP_PHASE?.trim() || "bootstrap";
  if (phase !== "bootstrap" && phase !== "finalize") {
    throw new Error("JCE_DB_SETUP_PHASE must be bootstrap or finalize.");
  }

  const connector = new Connector();
  let client;
  try {
    const connectionOptions = await connector.getOptions({
      instanceConnectionName,
      authType: "PASSWORD",
      ipType: process.env.JCE_DB_IP_TYPE?.trim() || "PUBLIC",
    });
    client = new Client({
      ...connectionOptions,
      database,
      user: "postgres",
      password: adminPassword,
    });
    await client.connect();
    await client.query("BEGIN");
    try {
      await ensureRole(client, migrationRole, "NOLOGIN NOBYPASSRLS");
      await ensureRole(client, runtimeRole, "NOLOGIN NOBYPASSRLS");

      const migration = quoteIdentifier(migrationRole);
      const runtime = quoteIdentifier(runtimeRole);
      const migrator = quoteIdentifier(migrationPrincipal);
      const runtimeUser = quoteIdentifier(runtimePrincipal);
      const databaseIdentifier = quoteIdentifier(database);

      await client.query(`REVOKE CREATE ON SCHEMA public FROM PUBLIC`);
      await client.query(`GRANT USAGE, CREATE ON SCHEMA public TO ${migration}`);
      await client.query(`GRANT CONNECT ON DATABASE ${databaseIdentifier} TO ${migration}`);
      await client.query(`GRANT CONNECT ON DATABASE ${databaseIdentifier} TO ${runtime}`);
      await client.query(`GRANT ${migration} TO ${migrator}`);
      await client.query(`GRANT ${runtime} TO ${runtimeUser}`);
      await client.query(`ALTER ROLE ${runtime} SET statement_timeout = '30s'`);
      await client.query(`ALTER ROLE ${runtime} SET lock_timeout = '5s'`);
      await client.query(
        `ALTER ROLE ${runtime} SET idle_in_transaction_session_timeout = '30s'`,
      );
      await client.query(`ALTER ROLE ${runtime} SET search_path = 'public'`);
      await client.query(`ALTER ROLE ${runtimeUser} SET statement_timeout = '30s'`);
      await client.query(`ALTER ROLE ${runtimeUser} SET lock_timeout = '5s'`);
      await client.query(
        `ALTER ROLE ${runtimeUser} SET idle_in_transaction_session_timeout = '30s'`,
      );
      await client.query(`ALTER ROLE ${runtimeUser} SET search_path = 'public'`);

      if (phase === "finalize") {
        await client.query(`GRANT ${migration} TO postgres`);
        await client.query(`SET LOCAL ROLE ${migration}`);
        await client.query(`GRANT USAGE ON SCHEMA public TO ${runtime}`);
        await client.query(
          `GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${runtime}`,
        );
        await client.query(
          `GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO ${runtime}`,
        );
        await client.query(
          `ALTER DEFAULT PRIVILEGES FOR ROLE ${migration} IN SCHEMA public ` +
            `GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${runtime}`,
        );
        await client.query(
          `ALTER DEFAULT PRIVILEGES FOR ROLE ${migration} IN SCHEMA public ` +
            `GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO ${runtime}`,
        );
        await client.query(`REVOKE ALL ON TABLE schema_migrations FROM ${runtime}`);
        await client.query(`RESET ROLE`);
        await client.query(`REVOKE ${migration} FROM postgres`);
      }

      await client.query("COMMIT");
      console.log(`Database roles ${phase} completed.`);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    }
  } finally {
    if (client) {
      await client.end();
    }
    connector.close();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
