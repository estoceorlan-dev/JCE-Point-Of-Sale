import {PoolClient} from "pg";
import {AuthorizedCommand, CommandResult, RemoteCommandError, requiredBoolean, requiredInteger, requiredString} from "./command_types";

export async function applyStockLocationCommand(client: PoolClient, command: AuthorizedCommand): Promise<CommandResult> {
  const creating = command.commandType === "stock_location.create";
  const editing = command.commandType === "stock_location.update";
  const archiving = command.commandType === "stock_location.archive";
  if (!creating && !editing && !archiving && command.commandType !== "stock_location.restore") {
    throw new RemoteCommandError("invalid-argument", "Unsupported stock location operation.");
  }
  await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
    [`stock-locations:${command.organizationId}:${command.branchId}`]);
  const scope = [command.aggregateId, command.organizationId, command.branchId];
  let current: Record<string, any> | undefined;
  let expectedVersion = 0;
  if (!creating) {
    expectedVersion = requiredInteger(command.payload, "expectedVersion");
    const found = await client.query(
      "SELECT * FROM stock_locations WHERE id = $1 AND organization_id = $2 AND branch_id = $3 FOR UPDATE", scope);
    current = found.rows[0];
    if (!current) throw new RemoteCommandError("not-found", "The location is outside the active branch.");
    if (expectedVersion < 0 || current.version !== expectedVersion) throw new RemoteCommandError("aborted", "The location changed. Refresh before trying again.");
  }
  if (creating || editing) {
    if (requiredString(command.payload, "id") !== command.aggregateId) throw new RemoteCommandError("invalid-argument", "Location IDs do not match.");
    const code = requiredString(command.payload, "code").trim().toUpperCase().replace(/\s+/g, "_");
    const name = requiredString(command.payload, "name").trim();
    const locationType = requiredString(command.payload, "locationType");
    const isDefault = requiredBoolean(command.payload, "isDefault");
    if (!/^[A-Z0-9][A-Z0-9_-]{1,19}$/.test(code) || name.length < 2 || name.length > 120 ||
        !["sales_floor", "warehouse", "returns", "damaged"].includes(locationType)) {
      throw new RemoteCommandError("invalid-argument", "The stock location profile is invalid.");
    }
    if (current && (!current.is_active || current.deleted_at)) throw new RemoteCommandError("failed-precondition", "Restore the location before editing it.");
    if (current?.is_default && !isDefault) throw new RemoteCommandError("failed-precondition", "Choose another default location first.");
    if (current && current.location_type !== locationType) await requireNoWork(client, command);
    const duplicate = await client.query(
      "SELECT id FROM stock_locations WHERE organization_id = $1 AND branch_id = $2 AND upper(btrim(code)) = $3 AND id <> $4 LIMIT 1",
      [command.organizationId, command.branchId, code, command.aggregateId]);
    if (duplicate.rowCount) throw new RemoteCommandError("already-exists", "A stock location with this code already exists.");
    const demoted = isDefault ? await client.query(
      `UPDATE stock_locations SET is_default = false, version = version + 1, updated_at = now()
       WHERE organization_id = $1 AND branch_id = $2 AND is_default = true AND id <> $3 RETURNING *`,
      [command.organizationId, command.branchId, command.aggregateId]) : {rows: []};
    const saved = creating ? await client.query(
      `INSERT INTO stock_locations (id, organization_id, branch_id, code, name, location_type,
       is_default, is_active, version, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, true, 0, now(), now()) RETURNING *`,
      [...scope, code, name, locationType, isDefault]) : await client.query(
      `UPDATE stock_locations SET code = $4, name = $5, location_type = $6,
       is_default = $7, version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND version = $8 RETURNING *`,
      [...scope, code, name, locationType, isDefault, expectedVersion]);
    return {stockLocation: saved.rows[0], demotedLocations: demoted.rows};
  }
  if (archiving) {
    if (!current!.is_active || current!.deleted_at) throw new RemoteCommandError("failed-precondition", "The location is already archived.");
    if (current!.is_default) throw new RemoteCommandError("failed-precondition", "Choose another default location before archiving.");
    const guard = await client.query(
      `SELECT (SELECT count(*) FROM stock_locations WHERE organization_id = $2 AND branch_id = $3
       AND is_active = true AND deleted_at IS NULL) AS active_count,
       EXISTS(SELECT 1 FROM inventory_balances WHERE stock_location_id = $1 AND organization_id = $2
       AND branch_id = $3 AND (on_hand_milli <> 0 OR reserved_milli <> 0)) AS has_stock`, scope);
    if (Number(guard.rows[0].active_count) < 2 || guard.rows[0].has_stock) {
      throw new RemoteCommandError("failed-precondition", "Keep an active location and reconcile all stock and reservations before archiving.");
    }
    await requireNoWork(client, command);
  } else if (current!.is_active && !current!.deleted_at) {
    throw new RemoteCommandError("failed-precondition", "The location is already active.");
  }
  const saved = await client.query(
    `UPDATE stock_locations SET is_active = $4, deleted_at = CASE WHEN $4 THEN NULL ELSE now() END,
     version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 AND version = $5 RETURNING *`,
    [...scope, !archiving, expectedVersion]);
  return {stockLocation: saved.rows[0]};
}

async function requireNoWork(client: PoolClient, command: AuthorizedCommand) {
  const guard = await client.query(
    `SELECT EXISTS(SELECT 1 FROM stock_counts WHERE stock_location_id = $1 AND organization_id = $2
     AND branch_id = $3 AND status = 'in_progress') AS has_count,
     EXISTS(SELECT 1 FROM stock_transfer_items i JOIN stock_transfers t ON t.id = i.transfer_id
       AND t.organization_id = i.organization_id WHERE i.organization_id = $2
       AND (i.source_stock_location_id = $1 OR i.destination_stock_location_id = $1 OR i.damaged_stock_location_id = $1)
       AND t.status IN ('draft', 'submitted', 'approved', 'shipped')) AS has_transfer`,
    [command.aggregateId, command.organizationId, command.branchId]);
  if (guard.rows[0].has_count || guard.rows[0].has_transfer) throw new RemoteCommandError("failed-precondition", "Finish active stock counts and transfers before changing this location.");
}
