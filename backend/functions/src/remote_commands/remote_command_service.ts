import {randomUUID} from "node:crypto";
import {DatabaseError, PoolClient} from "pg";

import {authorizeCommand} from "./command_authorization";
import {applyBranchCommand} from "./branch_commands";
import {
  AuthorizedCommand,
  CommandHandler,
  CommandResult,
  RemoteCommandError,
  RemoteCommandInput,
} from "./command_types";
import {applyInventoryCommand} from "./inventory_commands";
import {applyProductCommand} from "./product_commands";
import {applyPurchaseCommand} from "./purchase_commands";
import {completeSale} from "./sale_commands";
import {correctSale} from "./sale_correction_commands";
import {applyShiftCommand} from "./shift_commands";
import {applyStockCountCommand} from "./stock_count_commands";
import {applyTransferCommand} from "./transfer_commands";

type ProcessedOperationRow = {
  command_type: string;
  aggregate_type: string;
  aggregate_id: string;
  result_json: CommandResult;
};

export type RemoteCommandExecution = {
  operationId: string;
  duplicate: boolean;
  result: CommandResult;
};

export async function processRemoteCommand(
  client: PoolClient,
  input: RemoteCommandInput,
): Promise<RemoteCommandExecution> {
  await client.query("BEGIN");
  try {
    await client.query(
      "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      [`${input.organizationId}|${input.operationId}`],
    );
    const command = await authorizeCommand(client, input);
    const prior = await client.query<ProcessedOperationRow>(
      `
        SELECT command_type, aggregate_type, aggregate_id, result_json
        FROM processed_operations
        WHERE organization_id = $1 AND operation_id = $2
      `,
      [command.organizationId, command.operationId],
    );
    if (prior.rowCount === 1) {
      const existing = prior.rows[0];
      if (existing.command_type !== command.commandType ||
          existing.aggregate_type !== command.aggregateType ||
          existing.aggregate_id !== command.aggregateId) {
        throw new RemoteCommandError(
          "already-exists",
          "The operation ID was already used by another command.",
        );
      }
      await client.query("COMMIT");
      return {
        operationId: command.operationId,
        duplicate: true,
        result: existing.result_json,
      };
    }

    const result = await handlerFor(command.commandType)(client, command);
    await client.query(
      `
        INSERT INTO audit_logs (
          id, organization_id, branch_id, actor_user_id, firebase_uid,
          operation_id, action, entity_type, entity_id, metadata_json,
          occurred_at, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now(), now())
      `,
      [
        randomUUID(),
        command.organizationId,
        command.branchId,
        command.actorUserId,
        command.firebaseUid,
        command.operationId,
        command.commandType,
        command.aggregateType,
        command.aggregateId,
        {commandType: command.commandType},
      ],
    );
    await client.query(
      `
        INSERT INTO change_feed (
          organization_id, branch_id, aggregate_type, aggregate_id,
          operation_id, change_type, version, payload_json,
          occurred_at, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now(), now())
      `,
      [
        command.organizationId,
        changeFeedBranchId(command),
        command.aggregateType,
        command.aggregateId,
        command.operationId,
        changeType(command.commandType),
        resultVersion(result),
        {
          schemaVersion: 1,
          commandType: command.commandType,
          actorUserId: command.actorUserId,
          commandPayload: command.payload,
          result,
        },
      ],
    );
    await client.query(
      `
        INSERT INTO processed_operations (
          organization_id, operation_id, branch_id, command_type,
          aggregate_type, aggregate_id, actor_user_id, firebase_uid,
          result_json, processed_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
      `,
      [
        command.organizationId,
        command.operationId,
        command.branchId,
        command.commandType,
        command.aggregateType,
        command.aggregateId,
        command.actorUserId,
        command.firebaseUid,
        result,
      ],
    );
    await client.query("COMMIT");
    return {operationId: command.operationId, duplicate: false, result};
  } catch (error) {
    await client.query("ROLLBACK");
    throw mapDatabaseError(error);
  }
}

function changeType(commandType: string): "upsert" | "tombstone" {
  return commandType.endsWith(".archive") ? "tombstone" : "upsert";
}

function handlerFor(commandType: string): CommandHandler {
  if (commandType === "sale.complete") return completeSale;
  if (commandType === "sale.return" || commandType === "sale.void") {
    return correctSale;
  }
  if (commandType.startsWith("branch.")) return applyBranchCommand;
  if (commandType.startsWith("register.") || commandType.startsWith("shift.")) {
    return applyShiftCommand;
  }
  if (commandType.startsWith("stock_count.")) return applyStockCountCommand;
  if (commandType.startsWith("transfer.")) return applyTransferCommand;
  if (commandType.startsWith("supplier.") ||
      commandType.startsWith("purchase_order.")) {
    return applyPurchaseCommand;
  }
  if (commandType.startsWith("inventory.") || commandType.startsWith("stock_location.")) {
    return applyInventoryCommand;
  }
  if (commandType.startsWith("product") || commandType.startsWith("category.") ||
      commandType.startsWith("unit.")) {
    return applyProductCommand;
  }
  throw new RemoteCommandError("invalid-argument", `Unsupported command: ${commandType}.`);
}

function resultVersion(result: CommandResult): number {
  for (const candidate of Object.values(result)) {
    if (typeof candidate === "object" && candidate !== null &&
        typeof (candidate as Record<string, unknown>).version === "number") {
      return (candidate as Record<string, number>).version;
    }
  }
  return 0;
}

function changeFeedBranchId(command: AuthorizedCommand): string | null {
  if (command.aggregateType === "stock_transfer" ||
      command.aggregateType === "supplier") return null;
  if (["product", "category", "unit", "product_image"].includes(command.aggregateType)) {
    return null;
  }
  if (command.aggregateType === "product_price") {
    return typeof command.payload.branchId === "string" ? command.branchId : null;
  }
  return command.branchId;
}

function mapDatabaseError(error: unknown): unknown {
  if (error instanceof RemoteCommandError) return error;
  if (error instanceof DatabaseError) {
    if (error.code === "23505") {
      return new RemoteCommandError("already-exists", "A unique remote record already exists.");
    }
    if (error.code === "23503" || error.code === "23514" || error.code === "22P02") {
      return new RemoteCommandError("invalid-argument", "The command violates a remote data rule.");
    }
    if (error.code === "40001" || error.code === "40P01") {
      return new RemoteCommandError("aborted", "The command conflicted with another transaction. Retry it.");
    }
  }
  return error;
}
