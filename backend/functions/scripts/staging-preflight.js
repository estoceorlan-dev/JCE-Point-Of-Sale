// Infrastructure checks. --create-backup explicitly creates a staging backup;
// no migration/deployment action is available. Credentials are never printed.
const {GoogleAuth} = require("google-auth-library");

async function main() {
  const project = process.env.JCE_STAGING_PROJECT;
  if (!project || !project.includes("staging")) {
    throw new Error("JCE_STAGING_PROJECT must explicitly identify staging.");
  }
  const instance = process.env.JCE_STAGING_INSTANCE;
  if (!instance) throw new Error("JCE_STAGING_INSTANCE is required.");
  const auth = new GoogleAuth({scopes: ["https://www.googleapis.com/auth/cloud-platform"]});
  const client = await auth.getClient();
  const base = `https://sqladmin.googleapis.com/sql/v1beta4/projects/${encodeURIComponent(project)}/instances/${encodeURIComponent(instance)}`;
  const {data} = await client.request({url: base});
  if (process.argv.includes("--create-backup")) {
    const result = await client.request({url: `${base}/backupRuns`, method: "POST",
      data: {description: "Pre admin phases 0-2 staging migration"}});
    console.log(JSON.stringify({backupOperation: result.data.name, status: result.data.status}));
    return;
  }
  const backups = await client.request({url: `${base}/backupRuns`, params: {maxResults: 5}});
  const users = await client.request({url: `${base}/users`});
  console.log(JSON.stringify({
    project, instance: data.name, state: data.state,
    connectionName: data.connectionName,
    backupConfiguration: data.settings?.backupConfiguration,
    recentBackups: (backups.data.items || []).map((item) => ({
      id: item.id, status: item.status, endTime: item.endTime, type: item.type,
    })),
    databaseUsers: (users.data.items || []).map((item) => ({name: item.name, type: item.type})),
  }, null, 2));
}

main().catch((error) => {
  // Do not serialize request headers/configuration: they may contain tokens.
  console.error(JSON.stringify({
    status: error.response?.status,
    message: error.response?.data?.error?.message || error.message,
  }));
  process.exitCode = 1;
});
