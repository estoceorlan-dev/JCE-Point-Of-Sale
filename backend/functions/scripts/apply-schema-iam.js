const {Connector} = require("@google-cloud/cloud-sql-connector");
const {OAuth2Client} = require("google-auth-library");
const {Client} = require("pg");
const {applySchemaMigrations} = require("./schema-migrations");

function requiredEnvironmentValue(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

function createExplicitAuthClient() {
  const accessToken = process.env.JCE_GOOGLE_ACCESS_TOKEN?.trim();
  if (!accessToken) {
    return undefined;
  }

  const expiresAt = process.env.JCE_GOOGLE_ACCESS_TOKEN_EXPIRES_AT?.trim();
  const parsedExpiry = expiresAt ? Date.parse(expiresAt) : Number.NaN;
  const authClient = new OAuth2Client();
  authClient.setCredentials({
    access_token: accessToken,
    expiry_date: Number.isFinite(parsedExpiry)
      ? parsedExpiry
      : Date.now() + 50 * 60 * 1000,
  });
  return authClient;
}

async function main() {
  const instanceConnectionName = requiredEnvironmentValue(
    "JCE_DB_INSTANCE_CONNECTION_NAME",
  );
  const database = requiredEnvironmentValue("JCE_DB_NAME");
  const user = requiredEnvironmentValue("JCE_DB_USER");
  const auth = createExplicitAuthClient();
  const connector = new Connector(auth ? {auth} : undefined);
  let client;

  try {
    const connectionOptions = await connector.getOptions({
      instanceConnectionName,
      authType: "IAM",
      ipType: process.env.JCE_DB_IP_TYPE?.trim() || "PUBLIC",
    });
    client = new Client({
      ...connectionOptions,
      database,
      user,
    });
    await client.connect();
    const migrationRole = process.env.JCE_DB_MIGRATION_ROLE?.trim();
    if (migrationRole) {
      if (!/^[a-z_][a-z0-9_]*$/.test(migrationRole)) {
        throw new Error("JCE_DB_MIGRATION_ROLE is invalid.");
      }
      await client.query(`SET ROLE ${migrationRole}`);
    }
    await applySchemaMigrations(client);
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
