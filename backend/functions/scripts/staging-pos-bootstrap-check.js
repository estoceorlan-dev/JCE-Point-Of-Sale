// Authenticated, read-only verification of every deployed POS bootstrap
// collection. Credentials and tokens remain in memory and are never printed.
const assert = require("node:assert/strict");

const {
  callStaging,
  signInStaging,
} = require("./staging-auth-session");

const collections = [
  "organization",
  "branch",
  "registers",
  "categories",
  "units",
  "taxCategories",
  "products",
  "productBarcodes",
  "productPrices",
  "stockLocations",
  "inventoryBalances",
  "organizationSettings",
  "branchSettings",
  "reasonCodes",
  "featureFlags",
];

async function main() {
  const project = process.env.JCE_STAGING_PROJECT;
  if (!/^[a-z0-9-]*staging[a-z0-9-]*$/.test(project || "")) {
    throw new Error("An explicit staging project is required.");
  }

  const session = await signInStaging("Administrator");
  const profileResponse = await callStaging(
    session,
    "getMyAccessProfile",
    {},
  );
  assert.equal(profileResponse.httpStatus, 200, "Access profile failed.");
  assert.ok(!profileResponse.error, "Access profile returned an error.");

  const organizations = profileResponse.result?.organizations ?? [];
  const requestedOrganizationId = process.env.JCE_ACCESS_ORGANIZATION_ID;
  const membership = requestedOrganizationId ?
    organizations.find(
      (item) => item.organization.id === requestedOrganizationId,
    ) :
    organizations[0];
  assert.ok(membership, "No matching staging organization is available.");

  const requestedBranchId = process.env.JCE_ACCESS_BRANCH_ID;
  const branch = requestedBranchId ?
    membership.branches.find(
      (item) => item.branch.id === requestedBranchId,
    ) :
    membership.branches[0];
  assert.ok(branch, "No matching staging branch is available.");

  let snapshotToken;
  const results = [];
  for (const collection of collections) {
    let cursor;
    let pageCount = 0;
    let rowCount = 0;
    while (true) {
      const response = await callStaging(session, "getPosBootstrapPage", {
        organizationId: membership.organization.id,
        branchId: branch.branch.id,
        collection,
        snapshotToken,
        cursor,
        pageSize: 250,
      });
      assert.equal(
        response.httpStatus,
        200,
        `${collection} failed: ${response.error?.status ?? response.httpStatus}`,
      );
      assert.ok(!response.error, `${collection} returned an error.`);

      const page = response.result;
      assert.equal(page.collection, collection);
      assert.ok(Array.isArray(page.rows), `${collection} rows are invalid.`);
      if (snapshotToken === undefined) {
        snapshotToken = page.snapshotToken;
      } else {
        assert.equal(
          page.snapshotToken,
          snapshotToken,
          `${collection} changed snapshot scope.`,
        );
      }

      pageCount += 1;
      rowCount += page.rows.length;
      assert.ok(pageCount <= 1000, `${collection} exceeded the page limit.`);
      if (page.complete) break;
      assert.ok(page.nextCursor, `${collection} has no continuation cursor.`);
      cursor = page.nextCursor;
    }
    results.push({collection, pageCount, rowCount});
  }

  console.log(JSON.stringify({
    project,
    organizationId: membership.organization.id,
    branchId: branch.branch.id,
    collections: results,
    businessWrites: 0,
  }, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
