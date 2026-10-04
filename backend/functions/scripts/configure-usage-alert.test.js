const assert = require("node:assert/strict");
const test = require("node:test");
const {buildUsageAlert} = require("./configure-usage-alert");
test("usage alerts use the approved channel and bounded notification frequency", () => {
  const channel = "projects/test-production/notificationChannels/test";
  const alert = buildUsageAlert(channel);
  assert.deepEqual(alert.notificationChannels, [channel]);
  assert.equal(alert.alertStrategy.notificationRateLimit.period, "3600s");
  const filter = alert.conditions[0].conditionMatchedLog.filter;
  assert.match(filter, /usage_limit_denied/);
  assert.match(filter, /verifications.app/);
  assert.ok(!filter.includes("email"));
});
