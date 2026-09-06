import {PoolClient} from "pg";
import {AuthorizedCommand, CommandResult, RemoteCommandError,
  requiredBoolean, requiredInteger, requiredString} from "./command_types";

export async function applyTaxCategoryCommand(
  client: PoolClient, command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = requiredString(command.payload, "id");
  if (id !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Tax category IDs do not match.");
  }
  const returning = `id, code, name, rate_basis_points AS "rateBasisPoints",
    is_inclusive AS "isInclusive", is_active AS "isActive", version`;
  if (["tax_category.archive", "tax_category.restore"].includes(command.commandType)) {
    const active = command.commandType === "tax_category.restore";
    const result = await client.query(
      `UPDATE tax_categories SET is_active = $3,
        deleted_at = CASE WHEN $3 THEN NULL ELSE now() END,
        updated_at = now(), version = version + 1
       WHERE id = $1 AND organization_id = $2 RETURNING ${returning}`,
      [id, command.organizationId, active],
    );
    if (result.rowCount !== 1) throw new RemoteCommandError("not-found", "Tax category unavailable.");
    return {taxCategory: result.rows[0]};
  }
  if (!["tax_category.create", "tax_category.update"].includes(command.commandType)) {
    throw new RemoteCommandError("invalid-argument", "Unsupported tax category command.");
  }
  const code = requiredString(command.payload, "code").trim().toUpperCase();
  const name = requiredString(command.payload, "name").trim();
  const rate = requiredInteger(command.payload, "rateBasisPoints");
  const inclusive = requiredBoolean(command.payload, "isInclusive");
  if (!/^[A-Z0-9_-]{1,32}$/.test(code) || name.length < 2 || name.length > 80 ||
      rate < 0 || rate > 10000) {
    throw new RemoteCommandError("invalid-argument", "The tax category is invalid.");
  }
  const result = command.commandType === "tax_category.create" ?
    await client.query(
      `INSERT INTO tax_categories(id, organization_id, code, name, rate_basis_points, is_inclusive)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING ${returning}`,
      [id, command.organizationId, code, name, rate, inclusive],
    ) : await client.query(
      `UPDATE tax_categories SET code = $3, name = $4, rate_basis_points = $5,
       is_inclusive = $6, updated_at = now(), version = version + 1
       WHERE id = $1 AND organization_id = $2 AND deleted_at IS NULL RETURNING ${returning}`,
      [id, command.organizationId, code, name, rate, inclusive],
    );
  if (result.rowCount !== 1) throw new RemoteCommandError("not-found", "Tax category unavailable.");
  return {taxCategory: result.rows[0]};
}
