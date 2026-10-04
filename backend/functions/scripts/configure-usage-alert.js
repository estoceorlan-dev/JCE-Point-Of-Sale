"use strict";
const assert = require("node:assert/strict");
const {GoogleAuth} = require("google-auth-library");

function buildUsageAlert(channel) {
  return {
    displayName: "JCE POS production - access and usage protection",
    combiner: "OR", enabled: true, notificationChannels: [channel],
    conditions: [{displayName: "Usage quota or invalid callable attestation",
      conditionMatchedLog: {filter: 'resource.type="cloud_run_revision" AND ' +
        '(jsonPayload.event="usage_limit_denied" OR ' +
        'jsonPayload.verifications.app="INVALID" OR jsonPayload.verifications.auth="INVALID")'}}],
    alertStrategy: {notificationRateLimit: {period: "3600s"}, autoClose: "1800s"},
    documentation: {mimeType: "text/markdown", content:
      "Review scoped denial events, invitation/image/device bursts and App Check failures. " +
      "Do not disable core local sales or delete outbox data. Confirm legitimate backlog " +
      "recovery before changing deployment limits. This alert is not a spending cap."},
  };
}

async function main() {
  const project = process.env.JCE_PRODUCTION_PROJECT;
  const channel = process.env.JCE_USAGE_ALERT_CHANNEL;
  assert.ok(project && project === process.env.JCE_APPROVED_PRODUCTION_PROJECT_ID &&
    /^[a-z][a-z0-9-]*production[a-z0-9-]*$/.test(project));
  assert.ok(channel?.startsWith(`projects/${project}/notificationChannels/`));
  const policy = buildUsageAlert(channel);
  if (!process.argv.includes("--apply")) {
    console.log(JSON.stringify(policy, null, 2)); return;
  }
  const client = await new GoogleAuth({scopes: ["https://www.googleapis.com/auth/cloud-platform"]}).getClient();
  client.quotaProjectId = project;
  const root = "https://monitoring.googleapis.com/v3/";
  const notification = await client.request({url: root + channel});
  assert.equal(notification.data.enabled, true);
  const list = await client.request({url: `${root}projects/${project}/alertPolicies`});
  const matches = (list.data.alertPolicies || []).filter((entry) => entry.displayName === policy.displayName);
  assert.ok(matches.length <= 1, "Duplicate alert policies require review");
  if (matches.length) {
    console.log(JSON.stringify({status: "already-exists", name: matches[0].name,
      enabled: matches[0].enabled})); return;
  }
  const created = await client.request({url: `${root}projects/${project}/alertPolicies`,
    method: "POST", data: policy});
  console.log(JSON.stringify({status: "created", name: created.data.name, enabled: created.data.enabled}));
}
if (require.main === module) main().catch((error) => {
  console.error(error.response?.data?.error?.message || error.message); process.exitCode = 1;
});
module.exports = {buildUsageAlert};
