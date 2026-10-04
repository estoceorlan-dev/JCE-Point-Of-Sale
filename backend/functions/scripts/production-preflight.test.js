"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  loadProductionEnvironment,
} = require("./lib/production-environment");
const {
  assessProductionEnvironment,
} = require("./production-preflight");

function validEnvironment() {
  const project = "jce-pos-production-example";
  return {
    JCE_PRODUCTION_PROJECT: project,
    JCE_APPROVED_PRODUCTION_PROJECT_ID: project,
    JCE_FUNCTIONS_REGION: "asia-southeast1",
    JCE_PRODUCTION_INSTANCE: "jce-pos-instance",
    JCE_DB_INSTANCE_CONNECTION_NAME:
      `${project}:asia-southeast1:jce-pos-instance`,
    JCE_DB_NAME: "jce-pos-database",
    JCE_DB_USER: "jce-pos-functions",
    JCE_FUNCTIONS_SERVICE_ACCOUNT:
      `jce-pos-functions@${project}.iam.gserviceaccount.com`,
    JCE_SQL_CONNECT_SERVICE: "jce-pos-service",
    JCE_PRODUCTION_STORAGE_BUCKET: `${project}.firebasestorage.app`,
    JCE_PRODUCTION_HOSTING_SITE: project,
    JCE_PRODUCTION_OWNER_LABEL: "jce-pos-project",
    JCE_PRODUCTION_COST_CENTER_LABEL: "jce-pos-pilot",
    JCE_SQL_AVAILABILITY_TYPE: "ZONAL",
  };
}

function successful(data) {
  return {ok: true, data};
}

function completeChecks(config) {
  return {
    project: successful({
      projectNumber: "123",
      lifecycleState: "ACTIVE",
      labels: {
        environment: "production",
        owner: config.ownerLabel,
        cost_center: config.costCenterLabel,
      },
    }),
    billingInfo: successful({billingEnabled: true}),
    firebaseProject: successful({projectId: config.project}),
    androidApps: successful({
      apps: [{packageName: "com.jce.pos", state: "ACTIVE"}],
    }),
    webApps: successful({apps: [{state: "ACTIVE"}]}),
    sqlInstance: successful({
      name: config.instance,
      state: "RUNNABLE",
      connectionName: config.connectionName,
      settings: {
        availabilityType: config.sqlAvailabilityType,
        backupConfiguration: {
          enabled: true,
          pointInTimeRecoveryEnabled: true,
        },
        deletionProtectionEnabled: true,
      },
      ipAddresses: [{type: "PRIVATE"}],
    }),
    sqlBackups: successful({
      items: [{id: "backup-1", status: "SUCCESSFUL", type: "AUTOMATED"}],
    }),
    sqlUsers: successful({
      items: [{name: config.databaseUser, type: "CLOUD_IAM_SERVICE_ACCOUNT"}],
    }),
    sqlDatabases: successful({items: [{name: config.database}]}),
    iamPolicy: successful({
      bindings: [{
        role: "roles/cloudsql.client",
        members: [`serviceAccount:${config.runtimeServiceAccount}`],
      }],
    }),
    runtimeServiceAccount: successful({
      email: config.runtimeServiceAccount,
      disabled: false,
    }),
    storageBucket: successful({
      name: config.storageBucket,
      projectNumber: "123",
    }),
    hostingSite: successful({name: config.hostingSite}),
    sqlConnectService: successful({name: config.sqlConnectService}),
  };
}

test("accepts a self-consistent isolated production environment", () => {
  const config = loadProductionEnvironment(validEnvironment());
  assert.equal(config.project, "jce-pos-production-example");
  assert.equal(
    config.connectionName,
    "jce-pos-production-example:asia-southeast1:jce-pos-instance",
  );
});

test("rejects a project that does not match independent approval", () => {
  const environment = validEnvironment();
  environment.JCE_APPROVED_PRODUCTION_PROJECT_ID = "different-production";
  assert.throws(
    () => loadProductionEnvironment(environment),
    /independently approved project ID/,
  );
});

test("rejects staging and cross-project database configuration", () => {
  const staging = validEnvironment();
  staging.JCE_PRODUCTION_PROJECT = "jce-pos-staging-259528";
  staging.JCE_APPROVED_PRODUCTION_PROJECT_ID = "jce-pos-staging-259528";
  assert.throws(() => loadProductionEnvironment(staging), /production/);

  const connection = validEnvironment();
  connection.JCE_DB_INSTANCE_CONNECTION_NAME =
    "foreign-production:asia-southeast1:jce-pos-instance";
  assert.throws(() => loadProductionEnvironment(connection), /must match/);
});

test("accepts complete isolated resources and recovery controls", () => {
  const config = loadProductionEnvironment(validEnvironment());
  const summary = assessProductionEnvironment(config, completeChecks(config));

  assert.deepEqual(summary.failures, []);
  assert.equal(summary.sql.expectedDatabasePresent, true);
  assert.equal(summary.sql.expectedDatabaseUserPresent, true);
  assert.equal(summary.sql.backupEnabled, true);
  assert.equal(summary.sql.pitrEnabled, true);
  assert.equal(summary.sql.deletionProtection, true);
  assert.equal(summary.sql.availabilityType, "ZONAL");
  assert.equal(summary.billingEnabled, true);
  assert.equal(summary.clientApps.androidPackagePresent, true);
  assert.equal(summary.clientApps.activeWebCount, 1);
});

test("reports unavailable resources and privileged runtime IAM without throwing", () => {
  const config = loadProductionEnvironment(validEnvironment());
  const checks = completeChecks(config);
  checks.project = successful({
    projectNumber: "123",
    lifecycleState: "ACTIVE",
    labels: {},
  });
  checks.billingInfo = successful({billingEnabled: false});
  checks.androidApps = successful({apps: []});
  checks.webApps = successful({apps: []});
  checks.sqlInstance = {ok: false, status: 404, reason: "NOT_FOUND"};
  checks.iamPolicy = successful({
    bindings: [{
      role: "roles/storage.objectAdmin",
      members: [`serviceAccount:${config.runtimeServiceAccount}`],
    }],
  });

  const summary = assessProductionEnvironment(config, checks);

  assert.ok(summary.failures.some((failure) =>
    failure.includes("sqlInstance is unavailable")));
  assert.ok(summary.failures.includes(
    "Runtime identity has a prohibited project-wide privileged role.",
  ));
  assert.ok(summary.failures.includes(
    "Project environment label is not production.",
  ));
  assert.ok(summary.failures.includes(
    "Project owner label does not match the approved configuration.",
  ));
  assert.ok(summary.failures.includes(
    "Project cost-center label does not match the approved configuration.",
  ));
  assert.ok(summary.failures.includes("Cloud Billing is disabled."));
  assert.ok(summary.failures.includes(
    "The production Android app registration was not found.",
  ));
  assert.ok(summary.failures.includes(
    "No active production web app registration was found.",
  ));
});
