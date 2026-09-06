// Isolated staging account enrolled through the real staff invite workflow.
// Reserved invalid email domain, no email sent, credentials only in memory.
const {randomUUID, randomBytes} = require("node:crypto");
const assert = require("node:assert/strict");
const {signInStagingIdentity, callStaging} = require("./staging-auth-session");

async function createStagingCashier(admin, organizationId, branchId) {
  const roleId = randomUUID(); const userId = randomUUID();
  const email = `qa-${userId}@example.invalid`;
  const password = `Qa!9${randomBytes(24).toString("base64url")}`;
  const okay = (response) => {
    assert.equal(response.httpStatus, 200, `Fixture callable failed: ${response.error?.status || response.httpStatus}`);
    assert.ok(!response.error); return response.result;
  };
  const command = (type, aggregateType, aggregateId, payload) => callStaging(admin, "applyRemoteCommand",
    {operationId: randomUUID(), organizationId, branchId, commandType: type, aggregateType, aggregateId, payload});
  let session;
  async function cleanup() {
    const snapshot = okay(await callStaging(admin, "getAdministrationSnapshot", {organizationId}));
    const user = snapshot.users.find((row) => row.id === userId);
    if (user && user.status !== "disabled") {
      okay(await command("user.status.set", "app_user", userId, {expectedVersion: user.version, status: "disabled"}));
    }
    const role = snapshot.roles.find((row) => row.id === roleId);
    if (role?.isActive) okay(await command("role.archive", "role", roleId, {expectedVersion: role.version}));
    if (session) {
      const access = await callStaging(session, "getMyAccessProfile", {});
      assert.ok(["NOT_FOUND", "PERMISSION_DENIED"].includes(access.error?.status));
      const response = await fetch(`https://securetoken.googleapis.com/v1/token?key=${session.apiKey}`, {
        method: "POST", headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: new URLSearchParams({grant_type: "refresh_token", refresh_token: session.refreshToken}),
        signal: AbortSignal.timeout(30000),
      });
      const result = await response.json();
      assert.equal(response.ok, false, "Disabled fixture refresh token unexpectedly remained usable.");
      assert.ok(["TOKEN_EXPIRED", "USER_DISABLED", "INVALID_REFRESH_TOKEN"].includes(result.error?.message));
    }
    console.log(JSON.stringify({fixtureUserId: userId, fixtureRoleId: roleId,
      cleanup: "staff disabled, assignments revoked, role archived; history retained",
      refreshTokenRevocationVerified: !!session}));
  }
  console.log(JSON.stringify({fixtureUserId: userId, fixtureRoleId: roleId, purpose: "staging cashier/invite acceptance"}));
  try {
    okay(await command("role.create", "role", roleId, {id: roleId, code: `qa_${roleId.slice(0, 8)}`,
      name: "QA cashier acceptance", permissions: ["sales.process"]}));
    okay(await command("user.invite", "app_user", userId, {id: userId, email,
      displayName: "QA cashier acceptance", assignments: [{id: randomUUID(), roleId, branchId}]}));
    const invite = okay(await callStaging(admin, "generateStaffInviteLink", {organizationId, userId}));
    const oobCode = new URL(invite.inviteUrl).searchParams.get("oobCode");
    assert.ok(oobCode, "The generated invitation has no setup code.");
    const setup = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:resetPassword?key=${admin.apiKey}`, {
      method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify({oobCode, newPassword: password}), signal: AbortSignal.timeout(30000),
    });
    if (!setup.ok) throw new Error(`Fixture password setup failed (${setup.status}).`);
    session = await signInStagingIdentity(email, password);
    const acceptance = okay(await callStaging(session, "acceptStaffInvitation", {organizationId}));
    assert.equal(acceptance.acceptedCount, 1);
    const replay = okay(await callStaging(session, "acceptStaffInvitation", {organizationId}));
    assert.equal(replay.acceptedCount, 0);
    console.log(JSON.stringify({check: "invite identity creation, transient link, password setup, acceptance and replay", passed: true}));
    return {session, cleanup};
  } catch (error) {
    await cleanup(); throw error;
  }
}
module.exports = {createStagingCashier};
