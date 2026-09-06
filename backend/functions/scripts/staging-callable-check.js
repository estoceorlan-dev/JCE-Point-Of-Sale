// Concurrent unauthenticated negative probes: no credentials or business data.
async function main() {
  const project = process.env.JCE_STAGING_PROJECT;
  const region = process.env.JCE_FUNCTIONS_REGION;
  if (!project?.includes("staging") || !/^[a-z0-9-]+$/.test(project) ||
      !region || !/^[a-z0-9-]+$/.test(region)) {
    throw new Error("Explicit staging project and Functions region are required.");
  }
  const functions = ["getMyAccessProfile", "applyRemoteCommand", "registerDevice",
    "updateBranchName", "finalizeProductImage", "generateStaffInviteLink",
    "acceptStaffInvitation", "getAdministrationSnapshot"];
  const results = await Promise.all(Array.from({length: functions.length * 2}, async (_, index) => {
    const name = functions[index % functions.length];
    const response = await fetch(`https://${region}-${project}.cloudfunctions.net/${name}`, {
      method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify({data: {}}), signal: AbortSignal.timeout(30000),
    });
    const body = response.headers.get("content-type")?.includes("application/json") ?
      await response.json() : {};
    const rejected = response.status === 401 && body.error?.status === "UNAUTHENTICATED";
    return {function: name, httpStatus: response.status, rejected};
  }));
  console.log(JSON.stringify({results, scope: "unauthenticated rejection only; not signed-in workflow concurrency"}, null, 2));
  if (results.some((result) => !result.rejected)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
