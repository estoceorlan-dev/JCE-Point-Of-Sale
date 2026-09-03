const fs = require("node:fs/promises");
const path = require("node:path");
const crypto = require("node:crypto");

const requiredTables = [
  "app_users",
  "approval_decisions",
  "approval_requests",
  "audit_logs",
  "branch_settings",
  "branches",
  "change_feed",
  "devices",
  "feature_flags",
  "inventory_balances",
  "inventory_ledger_entries",
  "inventory_transactions",
  "organizations",
  "organization_settings",
  "number_sequences",
  "permissions",
  "processed_operations",
  "products",
  "refund_payments",
  "reason_codes",
  "role_permissions",
  "roles",
  "sales",
  "sale_return_items",
  "sale_returns",
  "shifts",
  "user_role_assignments",
];

async function applySchemaMigrations(client) {
  const migrationsPath = path.resolve(
    __dirname,
    "..",
    "..",
    "sql",
    "migrations",
  );

  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name text PRIMARY KEY,
      checksum text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  `);
  const migrationNames = (await fs.readdir(migrationsPath))
    .filter((name) => /^\d{4}_[a-z0-9_]+\.sql$/.test(name))
    .sort();
  if (migrationNames.length === 0) {
    throw new Error("No PostgreSQL migrations were found.");
  }

  for (const name of migrationNames) {
    const sql = await fs.readFile(path.join(migrationsPath, name), "utf8");
    const checksum = crypto.createHash("sha256").update(sql).digest("hex");
    const applied = await client.query(
      "SELECT checksum FROM schema_migrations WHERE name = $1",
      [name],
    );
    if (applied.rowCount === 1) {
      if (applied.rows[0].checksum !== checksum) {
        throw new Error(
          `Applied migration ${name} has changed; add a new migration instead.`,
        );
      }
      continue;
    }

    await client.query("BEGIN");
    try {
      await client.query(sql);
      await client.query(
        "INSERT INTO schema_migrations (name, checksum) VALUES ($1, $2)",
        [name, checksum],
      );
      await client.query("COMMIT");
      console.log(`Applied ${name}.`);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    }
  }

  const result = await client.query(
    `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = ANY($1::text[])
      ORDER BY table_name
    `,
    [requiredTables],
  );
  if (result.rowCount !== requiredTables.length) {
    throw new Error(
      `Schema verification found ${result.rowCount ?? 0} of ` +
        `${requiredTables.length} tables.`,
    );
  }
  console.log("PostgreSQL migrations applied and Phase 14 schema verified.");
}

module.exports = {applySchemaMigrations};
