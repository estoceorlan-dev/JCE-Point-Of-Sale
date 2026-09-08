import {PoolClient} from "pg";
import {authorizeCommand} from "./remote_commands/command_authorization";

export async function loadStockLocationsSnapshot(client: PoolClient, input: {
  firebaseUid: string; organizationId: string; branchId: string;
}) {
  await client.query("BEGIN ISOLATION LEVEL REPEATABLE READ");
  try {
    // Existing branch-aware inventory permission check; no organization-wide
    // directory permission is inferred and no records are mutated.
    await authorizeCommand(client, {...input, commandType: "stock_location.snapshot",
      aggregateType: "stock_location", aggregateId: input.branchId, operationId: "snapshot", payload: {}});
    const result = await client.query(
      "SELECT * FROM stock_locations WHERE organization_id = $1 AND branch_id = $2 ORDER BY id",
      [input.organizationId, input.branchId]);
    await client.query("COMMIT");
    return {schemaVersion: 1, organizationId: input.organizationId, branchId: input.branchId,
      locations: result.rows.map((row) => Object.fromEntries(Object.entries(row).map(
        ([key, value]) => [key, value instanceof Date ? value.toISOString() : value])))};
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}
