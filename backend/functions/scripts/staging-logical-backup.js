// Dump application-owned public schema through IAM, restore into an isolated
// local cluster, then rehearse migrations. Never migrates the remote database.
const {Connector} = require("@google-cloud/cloud-sql-connector");
const {Client} = require("pg");
const {spawn} = require("node:child_process");
const fs = require("node:fs/promises");
const net = require("node:net");
const path = require("node:path");
const crypto = require("node:crypto");
const {applySchemaMigrations} = require("./schema-migrations");
const {verifyAdministrationMigration} = require("./verify-administration-migration");

function run(binary, args, env = process.env) {
  return new Promise((resolve, reject) => {
    const child = spawn(binary, args, {env, windowsHide: true, stdio: ["ignore", "pipe", "pipe"]});
    let stderr = "";
    child.stdout.resume();
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("error", reject);
    child.on("exit", (code) => code === 0 ? resolve() : reject(new Error(
      `${path.basename(binary)} failed (${code}): ${stderr.slice(0, 1200)}`,
    )));
  });
}

async function main() {
  const instance = process.env.JCE_DB_INSTANCE_CONNECTION_NAME;
  const user = process.env.JCE_DB_USER;
  const database = process.env.JCE_DB_NAME;
  const backupRoot = process.env.JCE_BACKUP_DIRECTORY;
  const bin = process.env.JCE_POSTGRES_BIN;
  if (!instance?.split(":")[0].includes("staging") || !user || !database || !backupRoot || !bin) {
    throw new Error("Explicit staging connection, backup directory and PostgreSQL bin directory are required.");
  }
  const connector = new Connector();
  const sockets = new Set();
  let proxy, localClient, started = false, folder;
  const exe = (name) => path.join(bin, `${name}${process.platform === "win32" ? ".exe" : ""}`);
  const manifest = {instance, database, scope: "public schema, data, ownership and ACLs; no global roles or Firebase Auth export",
    createdAt: new Date().toISOString(), remoteBusinessWrites: 0, restoreVerified: false, migrationsRehearsed: false};
  try {
    folder = await fs.mkdtemp(path.join(backupRoot, "staging-"));
    const dump = path.join(folder, "public.dump");
    const cluster = path.join(folder, "restore-cluster");
    const options = await connector.getOptions({instanceConnectionName: instance, authType: "IAM", ipType: "PUBLIC"});
    proxy = net.createServer((socket) => {
      const upstream = options.stream();
      sockets.add(socket); sockets.add(upstream);
      socket.on("error", () => upstream.destroy());
      upstream.on("error", () => socket.destroy());
      socket.on("close", () => { upstream.destroy(); sockets.delete(socket); sockets.delete(upstream); });
      socket.pipe(upstream).pipe(socket);
    });
    await new Promise((resolve, reject) => { proxy.once("error", reject); proxy.listen(0, "127.0.0.1", resolve); });
    const dumpEnv = {...process.env, PGSSLMODE: "disable", PGCONNECT_TIMEOUT: "15",
      PGOPTIONS: "-c default_transaction_read_only=on -c lock_timeout=5000"};
    await run(exe("pg_dump"), ["--host=127.0.0.1", `--port=${proxy.address().port}`,
      `--username=${user}`, `--dbname=${database}`, "--no-password", "--format=custom",
      "--schema=public", `--file=${dump}`], dumpEnv);
    manifest.sha256 = crypto.createHash("sha256").update(await fs.readFile(dump)).digest("hex");
    manifest.bytes = (await fs.stat(dump)).size;
    console.log(JSON.stringify({backupCreated: dump, sha256: manifest.sha256, bytes: manifest.bytes}));
    await run(exe("pg_restore"), ["--list", dump]);
    await run(exe("initdb"), ["-D", cluster, "-U", "postgres", "--auth=trust", "--encoding=UTF8", "--no-locale"]);
    const portProbe = net.createServer();
    await new Promise((resolve) => portProbe.listen(0, "127.0.0.1", resolve));
    const port = portProbe.address().port;
    await new Promise((resolve) => portProbe.close(resolve));
    await run(exe("pg_ctl"), ["-D", cluster, "-l", path.join(folder, "restore-server.log"),
      "-o", `-h 127.0.0.1 -p ${port}`, "-w", "start"]);
    started = true;
    // initdb creates an empty public schema. The dump recreates it with its
    // original metadata, so remove only that empty schema in this new cluster.
    localClient = new Client({host: "127.0.0.1", port, user: "postgres", database: "postgres"});
    await localClient.connect();
    await localClient.query("DROP SCHEMA public");
    await run(exe("pg_restore"), ["--host=127.0.0.1", `--port=${port}`, "--username=postgres",
      "--dbname=postgres", "--no-password", "--no-owner", "--no-acl", "--exit-on-error", dump],
    {...process.env, PGSSLMODE: "disable", PGOPTIONS: ""});
    const before = await localClient.query("SELECT count(*) AS count FROM pg_tables WHERE schemaname='public'");
    manifest.restoredTables = Number(before.rows[0].count);
    manifest.restoreVerified = true;
    console.log(JSON.stringify({restoreVerified: true, tables: manifest.restoredTables}));
    await applySchemaMigrations(localClient);
    await verifyAdministrationMigration(localClient);
    manifest.administrationRoleGrantsVerified = true;
    console.log(JSON.stringify({administrationRoleGrantsVerified: true,
      scope: "local rollback-only fixtures and migration replay; no automatic permission grants"}));
    manifest.migrationsRehearsed = true;
    manifest.appliedMigrations = (await localClient.query("SELECT name FROM schema_migrations ORDER BY name")).rows.map((row) => row.name);
    console.log(JSON.stringify({migrationsRehearsed: true, migrations: manifest.appliedMigrations}));
  } finally {
    if (localClient) await localClient.end();
    if (started) await run(exe("pg_ctl"), ["-D", path.join(folder, "restore-cluster"), "-m", "fast", "-w", "stop"]);
    for (const socket of sockets) socket.destroy();
    if (proxy) await new Promise((resolve) => proxy.close(resolve));
    connector.close();
    if (folder) await fs.writeFile(path.join(folder, "manifest.json"), JSON.stringify(manifest, null, 2));
  }
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
