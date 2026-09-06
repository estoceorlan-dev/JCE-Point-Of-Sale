// Update only the GraphQL contract of an existing externally migrated schema.
// Does not request SQL DDL or alter datasource/ownership settings.
const {GoogleAuth} = require("google-auth-library");
const fs = require("node:fs/promises");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

async function main() {
  const project = process.env.JCE_STAGING_PROJECT;
  const region = process.env.JCE_FUNCTIONS_REGION;
  const service = process.env.JCE_SQL_CONNECT_SERVICE;
  const instance = process.env.JCE_DB_INSTANCE_CONNECTION_NAME;
  const database = process.env.JCE_DB_NAME;
  const backupRoot = process.env.JCE_BACKUP_DIRECTORY;
  if (!/^[a-z0-9-]*staging[a-z0-9-]*$/.test(project || "") ||
      !/^[a-z0-9-]+$/.test(region || "") || !/^[a-z0-9-]+$/.test(service || "") ||
      instance?.split(":")[0] !== project || !database || !backupRoot) {
    throw new Error("Explicit staging schema identifiers and restricted backup directory required.");
  }
  const name = `projects/${project}/locations/${region}/services/${service}/schemas/main`;
  const base = "https://firebasedataconnect.googleapis.com/v1/";
  const client = await new GoogleAuth({scopes: ["https://www.googleapis.com/auth/cloud-platform"]}).getClient();
  const existing = (await client.request({url: base + name})).data;
  assert.equal(existing.datasources.length, 1);
  const datasource = existing.datasources[0].postgresql;
  assert.equal(datasource.database, database);
  assert.equal(datasource.cloudSql.instance, `projects/${project}/locations/${region}/instances/${instance.split(":")[2]}`);
  assert.equal(datasource.schemaValidation, "NONE", "Do not change this service's SQL ownership/validation mode.");
  assert.ok(existing.etag);
  const directory = path.resolve(__dirname, "../../../dataconnect/schema");
  const names = (await fs.readdir(directory)).filter((file) => file.endsWith(".gql")).sort();
  assert.ok(names.length);
  const source = {files: await Promise.all(names.map(async (file) => ({path: file, content: await fs.readFile(path.join(directory, file), "utf8")})))};
  const body = {name, etag: existing.etag, source};
  await client.request({url: base + name, method: "PATCH", params: {updateMask: "source", validateOnly: true}, data: body});
  console.log(JSON.stringify({schema: name, contractValidated: true, sqlValidation: "unchanged NONE", sqlDdlRequested: false}));
  if (!process.argv.includes("--apply")) return;
  const backup = await fs.mkdtemp(path.join(backupRoot, "schema-release-"));
  await fs.writeFile(path.join(backup, "previous-schema.json"), JSON.stringify(existing, null, 2));
  const update = (await client.request({url: base + name, method: "PATCH", params: {updateMask: "source"}, data: body})).data;
  assert.ok(update.name?.startsWith(`projects/${project}/locations/${region}/operations/`));
  console.log(JSON.stringify({operation: update.name, previousSchemaBackup: backup}));
  let operation = update;
  const deadline = Date.now() + 180000;
  while (!operation.done) {
    if (Date.now() > deadline) throw new Error(`Deployment still running; inspect operation ${update.name} before retrying.`);
    await new Promise((resolve) => setTimeout(resolve, 3000));
    operation = (await client.request({url: base + update.name})).data;
  }
  if (operation.error) throw new Error(`Schema operation failed: ${operation.error.message}`);
  const verified = (await client.request({url: base + name})).data;
  assert.deepEqual(verified.source, source);
  assert.deepEqual(verified.datasources, existing.datasources);
  const sha256 = crypto.createHash("sha256").update(JSON.stringify(source)).digest("hex");
  console.log(JSON.stringify({schemaDeployed: true, sha256, updatedAt: verified.updateTime, sqlDdlRequested: false}));
}
main().catch((error) => {
  console.error(error.response?.data?.error?.message || error.message); process.exitCode = 1;
});
