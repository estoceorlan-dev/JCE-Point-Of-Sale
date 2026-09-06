import {PoolClient} from "pg";
import {AuthorizedCommand, CommandResult, RemoteCommandError,
  requiredInteger, requiredString} from "./command_types";

export async function administerRegister(client: PoolClient, command: AuthorizedCommand): Promise<CommandResult> {
  const id = requiredString(command.payload, "registerId");
  const version = requiredInteger(command.payload, "expectedVersion");
  if (id !== command.aggregateId || version < 0) {
    throw new RemoteCommandError("invalid-argument", "Invalid register identity or version.");
  }
  const existing = await client.query(
    `SELECT * FROM registers WHERE id = $1 AND organization_id = $2 AND branch_id = $3 FOR UPDATE`,
    [id, command.organizationId, command.branchId],
  );
  const row = existing.rows[0];
  if (!row || row.version !== version) {
    throw new RemoteCommandError("aborted", "The register changed. Refresh and retry.");
  }
  const archive = command.commandType === "register.archive";
  const restore = command.commandType === "register.restore";
  const unassign = archive || command.commandType === "register.unassign_device";
  const edit = command.commandType === "register.update";
  if (!archive && !restore && !unassign && !edit) {
    throw new RemoteCommandError("invalid-argument", "Unsupported register command.");
  }
  if (!restore && (!row.is_active || row.deleted_at !== null)) {
    throw new RemoteCommandError("failed-precondition", "Restore this register first.");
  }
  if (unassign) {
    const shifts = await client.query(
      `SELECT 1 FROM shifts WHERE register_id = $1 AND organization_id = $2 AND status = 'open' LIMIT 1`,
      [id, command.organizationId],
    );
    if (shifts.rowCount !== 0) {
      throw new RemoteCommandError("failed-precondition", "Close the register's shift first.");
    }
  }
  const code = edit ? requiredString(command.payload, "code").trim().toUpperCase() : row.code;
  const name = edit ? requiredString(command.payload, "name").trim() : row.name;
  if (edit && (!/^[A-Z0-9_-]{2,20}$/.test(code) || name.length < 2 || name.length > 80)) {
    throw new RemoteCommandError("invalid-argument", "Invalid register code or name.");
  }
  const result = await client.query(
    `UPDATE registers SET code = $4, name = $5, is_active = $6,
      deleted_at = CASE WHEN $6 THEN NULL ELSE now() END,
      assigned_device_id = CASE WHEN $7 THEN NULL ELSE assigned_device_id END,
      assigned_by_user_id = CASE WHEN $7 THEN NULL ELSE assigned_by_user_id END,
      assigned_at = CASE WHEN $7 THEN NULL ELSE assigned_at END,
      updated_at = now(), version = version + 1
     WHERE id = $1 AND organization_id = $2 AND branch_id = $3 RETURNING *`,
    [id, command.organizationId, command.branchId, code, name, !archive, unassign],
  );
  return {register: result.rows[0]};
}
