import assert from "node:assert/strict";
import test from "node:test";
import {loadUsagePolicies} from "./usage_policy";
import {enforceUsageAdmission, OptionalFeatureDisabledError} from "./usage_admission";

test("paid optional features use hourly/daily windows, not minute defaults", () => {
  const policies = loadUsagePolicies("{}");
  assert.deepEqual(policies.staff_invite.user, {maximumRequests: 10, windowSeconds: 3600});
  assert.deepEqual(policies.staff_invite.organization, {maximumRequests: 50, windowSeconds: 86400});
  assert.deepEqual(policies.product_image.user, {maximumRequests: 20, windowSeconds: 3600});
  assert.equal(policies.remote_command.enabled, true);
});

test("operator policies are configurable but fail closed on malformed or unsafe input", () => {
  const policy = loadUsagePolicies(JSON.stringify({staff_invite: {
    user: {maximumRequests: 2}, enabled: false}})).staff_invite;
  assert.equal(policy.user.maximumRequests, 2);
  assert.equal(policy.user.windowSeconds, 3600);
  assert.equal(policy.enabled, false);
  for (const raw of ["null", "[]", "false", "bad", '{"unknown":{}}',
    '{"remote_command":{"enabled":false}}', '{"product_image":{"enabled":"false"}}',
    '{"staff_invite":{"user":{"maximumRequests":0}}}',
    '{"staff_invite":{"user":{"maximumRequests":1.5}}}',
    '{"staff_invite":{"user":{"windowSeconds":86401}}}',
    '{"staff_invite":{"unlimited":true}}', '{"access_profile":{"organization":{}}}']) {
    assert.throws(() => loadUsagePolicies(raw), raw);
  }
});

test("foreign organization IDs never charge shared counters; UID safety bound remains", async () => {
  const calls: {sql: string; values?: unknown[]}[] = [];
  const client = {async query(sql: string, values?: unknown[]) {
    calls.push({sql, values});
    return sql.includes("INSERT INTO api_rate_limit_windows") ?
      {rows: [{request_count: 2, retry_after_seconds: 60}]} : {rows: [], rowCount: 0};
  }};
  await enforceUsageAdmission(client as never, {firebaseUid: "user", scope: "remote_command",
    organizationId: "foreign", branchId: "branch", policy: loadUsagePolicies("{}").remote_command});
  assert.equal(calls.filter(({sql}) => sql.includes("INSERT INTO")).length, 1);
  assert.deepEqual(calls.at(-1)?.values, ["user", "foreign", "branch"]);
});

test("organization usage is shared across member identities, with no role exemption", async () => {
  const counters: unknown[][] = [];
  const client = {async query(sql: string, values?: unknown[]) {
    if (sql.includes("INSERT INTO api_rate_limit_windows")) {
      counters.push(values!);
      return {rows: [{request_count: 2, retry_after_seconds: 60}]};
    }
    return {rows: [{}], rowCount: 1};
  }};
  for (const uid of ["cashier", "administrator"]) {
    await enforceUsageAdmission(client as never, {firebaseUid: uid, scope: "product_image",
      organizationId: "org", policy: loadUsagePolicies("{}").product_image});
  }
  assert.notEqual(counters[0][0], counters[2][0]);
  assert.equal(counters[1][0], counters[3][0]);
  assert.equal(counters[1][2], 86400);
});

test("optional switch rejects before expensive work without disabling core scopes", async () => {
  let calls = 0;
  const client = {async query() {calls++; return {rows: [{request_count: 2}]};}};
  await assert.rejects(enforceUsageAdmission(client as never, {
    firebaseUid: "user", scope: "product_image", organizationId: "org",
    policy: loadUsagePolicies('{"product_image":{"enabled":false}}').product_image,
  }), OptionalFeatureDisabledError);
  assert.equal(calls, 1);
});
