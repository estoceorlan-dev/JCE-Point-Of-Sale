// Read-only production environment preflight. It never creates resources,
// changes IAM, takes backups, migrates data, deploys code, or prints credentials.
"use strict";

const {GoogleAuth} = require("google-auth-library");
const {
  loadProductionEnvironment,
} = require("./lib/production-environment");

async function main() {
  const config = loadProductionEnvironment(process.env);
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const client = await auth.getClient();
  client.quotaProjectId = config.project;
  const projectPath = `projects/${encodeURIComponent(config.project)}`;
  const sqlBase =
    "https://sqladmin.googleapis.com/sql/v1beta4/" +
    `${projectPath}/instances/${encodeURIComponent(config.instance)}`;

  async function read(name, request) {
    try {
      const response = await client.request({
        ...request,
        headers: {
          ...request.headers,
          "x-goog-user-project": config.project,
        },
      });
      return [name, {ok: true, data: response.data}];
    } catch (error) {
      const apiReason = error.response?.data?.error?.status;
      return [name, {
        ok: false,
        status: error.response?.status || null,
        reason: typeof apiReason === "string" ? apiReason :
          (typeof error.code === "string" ? error.code : "HTTP_ERROR"),
      }];
    }
  }

  const checks = Object.fromEntries(await Promise.all([
    read("project", {
      url: `https://cloudresourcemanager.googleapis.com/v1/${projectPath}`,
    }),
    read("billingInfo", {
      url: `https://cloudbilling.googleapis.com/v1/${projectPath}/billingInfo`,
    }),
    read("firebaseProject", {
      url: `https://firebase.googleapis.com/v1beta1/${projectPath}`,
    }),
    read("androidApps", {
      url: `https://firebase.googleapis.com/v1beta1/${projectPath}/androidApps`,
      params: {pageSize: 100},
    }),
    read("webApps", {
      url: `https://firebase.googleapis.com/v1beta1/${projectPath}/webApps`,
      params: {pageSize: 100},
    }),
    read("sqlInstance", {url: sqlBase}),
    read("sqlBackups", {
      url: `${sqlBase}/backupRuns`, params: {maxResults: 5},
    }),
    read("sqlUsers", {url: `${sqlBase}/users`}),
    read("sqlDatabases", {url: `${sqlBase}/databases`}),
    read("iamPolicy", {
      url: `https://cloudresourcemanager.googleapis.com/v1/${projectPath}:getIamPolicy`,
      method: "POST",
      data: {options: {requestedPolicyVersion: 3}},
    }),
    read("runtimeServiceAccount", {
      url: "https://iam.googleapis.com/v1/" +
        `${projectPath}/serviceAccounts/` +
        encodeURIComponent(config.runtimeServiceAccount),
    }),
    read("storageBucket", {
      url: `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(config.storageBucket)}`,
    }),
    read("hostingSite", {
      url: `https://firebasehosting.googleapis.com/v1beta1/${projectPath}/sites/${encodeURIComponent(config.hostingSite)}`,
    }),
    read("sqlConnectService", {
      url: "https://firebasedataconnect.googleapis.com/v1/" +
        `${projectPath}/locations/${encodeURIComponent(config.region)}/` +
        `services/${encodeURIComponent(config.sqlConnectService)}`,
    }),
  ]));

  const summary = assessProductionEnvironment(config, checks);
  console.log(JSON.stringify(summary, null, 2));
  if (summary.failures.length > 0) process.exitCode = 1;
}

function assessProductionEnvironment(config, checks) {
  const project = checks.project?.data;
  const billingInfo = checks.billingInfo?.data;
  const firebaseProject = checks.firebaseProject?.data;
  const androidApps = checks.androidApps?.data;
  const webApps = checks.webApps?.data;
  const instanceData = checks.sqlInstance?.data;
  const backups = checks.sqlBackups?.data;
  const users = checks.sqlUsers?.data;
  const databases = checks.sqlDatabases?.data;
  const policy = checks.iamPolicy?.data;
  const runtimeServiceAccount = checks.runtimeServiceAccount?.data;
  const bucket = checks.storageBucket?.data;
  const site = checks.hostingSite?.data;
  const service = checks.sqlConnectService?.data;
  const backupConfig = instanceData?.settings?.backupConfiguration || {};
  const successfulBackups = (backups?.items || [])
    .filter((item) => item.status === "SUCCESSFUL")
    .map((item) => ({id: item.id, endTime: item.endTime, type: item.type}));
  const runtimeMember = `serviceAccount:${config.runtimeServiceAccount}`;
  const runtimeRoles = (policy?.bindings || [])
    .filter((binding) => (binding.members || []).includes(runtimeMember))
    .map((binding) => binding.role)
    .sort();
  const prohibitedProjectRuntimeRoles = runtimeRoles.filter((role) =>
    [
      "roles/owner",
      "roles/editor",
      "roles/storage.admin",
      "roles/storage.objectAdmin",
    ].includes(role));
  const labels = project?.labels || {};
  const activeAndroidApps = (androidApps?.apps || [])
    .filter((app) => app.state !== "DELETED");
  const activeWebApps = (webApps?.apps || [])
    .filter((app) => app.state !== "DELETED");
  const failures = Object.entries(checks)
    .filter(([, result]) => !result.ok)
    .map(([name, result]) =>
      `${name} is unavailable (${result.status || "no-status"}/${result.reason}).`);

  if (project && project.lifecycleState !== "ACTIVE") failures.push("Project is not ACTIVE.");
  if (billingInfo && billingInfo.billingEnabled !== true) {
    failures.push("Cloud Billing is disabled.");
  }
  if (firebaseProject && firebaseProject.projectId !== config.project) failures.push("Firebase project mismatch.");
  if (androidApps && !activeAndroidApps.some((app) => app.packageName === "com.jce.pos")) {
    failures.push("The production Android app registration was not found.");
  }
  if (webApps && activeWebApps.length === 0) {
    failures.push("No active production web app registration was found.");
  }
  if (instanceData && instanceData.state !== "RUNNABLE") failures.push("Cloud SQL is not RUNNABLE.");
  if (instanceData && instanceData.connectionName !== config.connectionName) failures.push("Cloud SQL connection-name mismatch.");
  if (instanceData && instanceData.settings?.availabilityType !== config.sqlAvailabilityType) {
    failures.push("Cloud SQL availability type does not match the approved configuration.");
  }
  if (instanceData && backupConfig.enabled !== true) failures.push("Automated backups are disabled.");
  if (instanceData && backupConfig.pointInTimeRecoveryEnabled !== true) failures.push("PITR is disabled.");
  if (instanceData && instanceData.settings?.deletionProtectionEnabled !== true &&
      instanceData.deletionProtectionEnabled !== true) failures.push("Deletion protection is disabled.");
  if (backups && successfulBackups.length === 0) failures.push("No recent successful backup was found.");
  if (users && !(users.items || []).some((item) => item.name === config.databaseUser)) {
    failures.push("The configured production database user was not found.");
  }
  if (databases && !(databases.items || []).some((item) => item.name === config.database)) {
    failures.push("The configured production database was not found.");
  }
  if (policy && prohibitedProjectRuntimeRoles.length > 0) {
    failures.push(
      "Runtime identity has a prohibited project-wide privileged role.",
    );
  }
  if (runtimeServiceAccount && runtimeServiceAccount.email !== config.runtimeServiceAccount) {
    failures.push("Runtime service-account identity mismatch.");
  }
  if (runtimeServiceAccount?.disabled === true) {
    failures.push("Runtime service account is disabled.");
  }
  if (project && labels.environment !== "production") failures.push("Project environment label is not production.");
  if (project && labels.owner !== config.ownerLabel) failures.push("Project owner label does not match the approved configuration.");
  if (project && labels.cost_center !== config.costCenterLabel) failures.push("Project cost-center label does not match the approved configuration.");
  if (bucket && project &&
      bucket.projectNumber?.toString() !== project.projectNumber?.toString()) {
    failures.push("Storage bucket does not belong to the production project.");
  }

  return {
    project: config.project,
    projectNumber: project?.projectNumber || null,
    lifecycleState: project?.lifecycleState || null,
    environmentLabel: labels.environment || null,
    ownerLabel: labels.owner || null,
    costCenterLabel: labels.cost_center || null,
    billingEnabled: billingInfo?.billingEnabled === true,
    firebaseProject: firebaseProject?.projectId || null,
    clientApps: {
      androidPackagePresent: activeAndroidApps
        .some((app) => app.packageName === "com.jce.pos"),
      activeAndroidCount: activeAndroidApps.length,
      activeWebCount: activeWebApps.length,
    },
    region: config.region,
    sql: {
      instance: instanceData?.name || null,
      state: instanceData?.state || null,
      connectionName: instanceData?.connectionName || null,
      availabilityType: instanceData?.settings?.availabilityType || null,
      expectedAvailabilityType: config.sqlAvailabilityType,
      backupEnabled: backupConfig.enabled === true,
      pitrEnabled: backupConfig.pointInTimeRecoveryEnabled === true,
      deletionProtection:
        instanceData?.settings?.deletionProtectionEnabled === true ||
        instanceData?.deletionProtectionEnabled === true,
      successfulBackups,
      databaseUserCount: (users?.items || []).length,
      databaseUserTypes: [...new Set((users?.items || []).map((item) => item.type))],
      expectedDatabasePresent: (databases?.items || [])
        .some((item) => item.name === config.database),
      expectedDatabaseUserPresent: (users?.items || [])
        .some((item) => item.name === config.databaseUser),
      ipTypes: (instanceData?.ipAddresses || []).map((item) => item.type),
    },
    runtimeServiceAccount: runtimeServiceAccount?.email || null,
    runtimeRoles,
    storageBucket: bucket?.name || null,
    hostingSite: site?.name || null,
    sqlConnectService: service?.name || null,
    resourceChecks: Object.fromEntries(Object.entries(checks).map(
      ([name, result]) => [name, {
        ok: result.ok,
        status: result.status || null,
        reason: result.reason || null,
      }],
    )),
    failures,
  };
}

if (require.main === module) {
  main().catch((error) => {
    console.error(JSON.stringify({
      status: error.response?.status,
      message: error.response?.data?.error?.message || error.message,
    }));
    process.exitCode = 1;
  });
}

module.exports = {assessProductionEnvironment};
