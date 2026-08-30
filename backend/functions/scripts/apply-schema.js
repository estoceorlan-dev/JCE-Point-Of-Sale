const {Client} = require("pg");
const {applySchemaMigrations} = require("./schema-migrations");

async function main() {
  const connectionString = process.env.JCE_DATABASE_URL?.trim();
  if (!connectionString) {
    throw new Error("JCE_DATABASE_URL is required.");
  }

  const client = new Client({connectionString});
  await client.connect();
  try {
    await applySchemaMigrations(client);
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
