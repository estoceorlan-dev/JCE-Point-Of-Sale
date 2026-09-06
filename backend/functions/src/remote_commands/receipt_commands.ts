import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  optionalTimestamp,
  requiredString,
} from "./command_types";

export async function applyReceiptCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  if (command.commandType !== "receipt.reprint") {
    throw new RemoteCommandError(
      "invalid-argument",
      `Unsupported receipt command: ${command.commandType}.`,
    );
  }
  const id = requiredString(command.payload, "id");
  const saleId = requiredString(command.payload, "saleId");
  const registerId = requiredString(command.payload, "registerId");
  if (id !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Receipt event IDs do not match.");
  }
  const sale = await client.query(
    `SELECT 1 FROM sales
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3
       AND register_id = $4 AND status IN ('completed', 'partially_returned', 'returned', 'voided')`,
    [saleId, command.organizationId, command.branchId, registerId],
  );
  if (sale.rowCount !== 1) {
    throw new RemoteCommandError(
      "not-found",
      "The sale receipt is unavailable in the active branch.",
    );
  }
  const requestedAt = optionalTimestamp(command.payload, "requestedAt") ?? new Date();
  const result = await client.query(
    `INSERT INTO receipt_reprint_events (
       id, organization_id, branch_id, register_id, sale_id,
       requested_by_user_id, requested_at, created_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, now())
     RETURNING id, register_id, sale_id, requested_by_user_id, requested_at`,
    [
      id,
      command.organizationId,
      command.branchId,
      registerId,
      saleId,
      command.actorUserId,
      requestedAt,
    ],
  );
  return {receiptReprintEvent: result.rows[0]};
}
