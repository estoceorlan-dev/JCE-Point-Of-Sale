// Explicit operator-only staging IAM setup. No service-account keys are created.
const {GoogleAuth} = require("google-auth-library");
const assert = require("node:assert/strict");
const permissions = ["firebaseauth.users.create", "firebaseauth.users.get",
  "firebaseauth.users.sendEmail", "firebaseauth.users.update"];

async function main() {
  const project = process.env.JCE_STAGING_PROJECT;
  const serviceAccount = process.env.JCE_FUNCTIONS_SERVICE_ACCOUNT;
  const roleId = process.env.JCE_AUTH_ROLE_ID;
  if (!/^[a-z0-9-]*staging[a-z0-9-]*$/.test(project || "") ||
      !serviceAccount?.endsWith(`@${project}.iam.gserviceaccount.com`) ||
      !/^[a-zA-Z0-9_.]{3,64}$/.test(roleId || "")) {
    throw new Error("Explicit staging project, same-project runtime identity and custom role ID are required.");
  }
  const name = `projects/${project}/roles/${roleId}`;
  const member = `serviceAccount:${serviceAccount}`;
  if (!process.argv.includes("--apply")) {
    console.log(JSON.stringify({name, member, permissions, applied: false})); return;
  }
  const client = await new GoogleAuth({scopes: ["https://www.googleapis.com/auth/cloud-platform"]}).getClient();
  let role;
  try { role = (await client.request({url: `https://iam.googleapis.com/v1/${name}`})).data; }
  catch (error) { if (error.response?.status !== 404) throw error; }
  if (!role) {
    role = (await client.request({url: `https://iam.googleapis.com/v1/projects/${project}/roles`,
      method: "POST", data: {roleId, role: {title: "JCE staff identity management",
        description: "Staff identity lookup, creation, invitation links and token revocation; no deletion or session creation.",
        includedPermissions: permissions, stage: "GA"}}})).data;
  }
  assert.equal(!!role.deleted, false, "The existing role is deleted.");
  assert.deepEqual([...role.includedPermissions].sort(), [...permissions].sort(),
    "Do not reuse or modify an existing custom role with different permissions.");
  const policyUrl = `https://cloudresourcemanager.googleapis.com/v1/projects/${project}`;
  const {data: policy} = await client.request({url: `${policyUrl}:getIamPolicy`,
    method: "POST", data: {options: {requestedPolicyVersion: 3}}});
  assert.ok(policy.etag, "An IAM policy etag is required to avoid lost concurrent changes.");
  policy.bindings ??= [];
  let binding = policy.bindings.find((item) => item.role === name && !item.condition);
  if (!binding) { binding = {role: name, members: []}; policy.bindings.push(binding); }
  if (!binding.members.includes(member)) {
    binding.members.push(member);
    await client.request({url: `${policyUrl}:setIamPolicy`, method: "POST", data: {policy}});
  }
  const verified = (await client.request({url: `${policyUrl}:getIamPolicy`,
    method: "POST", data: {options: {requestedPolicyVersion: 3}}})).data;
  assert.ok(verified.bindings.some((item) => item.role === name && !item.condition && item.members.includes(member)));
  console.log(JSON.stringify({role: name, member, permissions, verified: true}));
}
main().catch((error) => {
  console.error(error.response?.data?.error?.message || error.message); process.exitCode = 1;
});
