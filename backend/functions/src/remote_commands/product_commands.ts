import {randomUUID} from "node:crypto";
import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  normalizeSearch,
  optionalString,
  optionalTimestamp,
  requiredArray,
  requiredBoolean,
  requiredInteger,
  requiredString,
} from "./command_types";

export async function applyProductCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  switch (command.commandType) {
    case "product.create":
      return upsertProduct(client, command, true);
    case "product.update":
      return upsertProduct(client, command, false);
    case "product.archive":
    case "product.restore":
      return setProductArchived(client, command);
    case "product_price.create":
      return createProductPrice(client, command);
    case "category.create":
    case "category.update":
      return upsertCategory(client, command);
    case "category.archive":
    case "category.restore":
      return setSimpleArchived(client, command, "categories");
    case "unit.create":
    case "unit.update":
      return upsertUnit(client, command);
    case "unit.archive":
    case "unit.restore":
      return setSimpleArchived(client, command, "units");
    default:
      throw new RemoteCommandError(
        "invalid-argument",
        `Unsupported catalog command: ${command.commandType}.`,
      );
  }
}

async function upsertProduct(
  client: PoolClient,
  command: AuthorizedCommand,
  creating: boolean,
): Promise<CommandResult> {
  const payload = command.payload;
  const id = requiredString(payload, "id");
  if (id !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Product IDs do not match.");
  }
  const sku = requiredString(payload, "sku");
  const name = requiredString(payload, "name");
  const unitId = requiredString(payload, "unitId");
  const categoryId = optionalString(payload, "categoryId");
  const taxCategoryId = optionalString(payload, "taxCategoryId");
  const description = optionalString(payload, "description");
  const existing = await client.query<{version: number}>(
    `SELECT version FROM products WHERE id = $1 AND organization_id = $2 FOR UPDATE`,
    [id, command.organizationId],
  );
  if (creating && existing.rowCount !== 0) {
    throw new RemoteCommandError("already-exists", "The product already exists.");
  }
  if (!creating && existing.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The product does not exist.");
  }
  if (!creating) {
    requireExpectedVersion(payload, existing.rows[0].version, "product");
  }

  await requireCatalogReference(client, "units", unitId, command.organizationId);
  if (categoryId !== null) {
    await requireCatalogReference(client, "categories", categoryId, command.organizationId);
  }
  if (taxCategoryId !== null) {
    await requireCatalogReference(client, "tax_categories", taxCategoryId, command.organizationId);
  }

  if (creating) {
    await client.query(
      `
        INSERT INTO products (
          id, organization_id, category_id, unit_id, tax_category_id,
          sku, normalized_sku, name, normalized_name, description,
          is_active, version, created_at, updated_at, deleted_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, true, 0, now(), now(), NULL)
      `,
      [
        id,
        command.organizationId,
        categoryId,
        unitId,
        taxCategoryId,
        sku,
        normalizeSearch(sku),
        name,
        normalizeSearch(name),
        description,
      ],
    );
  } else {
    await client.query(
      `
        UPDATE products SET
          category_id = $3,
          unit_id = $4,
          tax_category_id = $5,
          sku = $6,
          normalized_sku = $7,
          name = $8,
          normalized_name = $9,
          description = $10,
          version = version + 1,
          updated_at = now()
        WHERE id = $1 AND organization_id = $2
      `,
      [
        id,
        command.organizationId,
        categoryId,
        unitId,
        taxCategoryId,
        sku,
        normalizeSearch(sku),
        name,
        normalizeSearch(name),
        description,
      ],
    );
  }

  await replaceBarcodes(client, command, id);
  const unitPriceMinor = payload.unitPriceMinor;
  if (unitPriceMinor !== undefined && unitPriceMinor !== null) {
    await appendPriceIfChanged(client, command, id);
  }
  const product = await productPayload(client, command.organizationId, id);
  return {product};
}

async function replaceBarcodes(
  client: PoolClient,
  command: AuthorizedCommand,
  productId: string,
): Promise<void> {
  const barcodes = requiredArray(command.payload, "barcodes").map((value) => {
    if (typeof value !== "string" || value.trim().length === 0) {
      throw new RemoteCommandError("invalid-argument", "Every barcode must be a string.");
    }
    return value.trim();
  });
  const normalized = barcodes.map(normalizeSearch);
  if (new Set(normalized).size !== normalized.length) {
    throw new RemoteCommandError("invalid-argument", "Product barcodes must be unique.");
  }
  if (normalized.length > 0) {
    const conflicts = await client.query<{product_id: string}>(
      `
        SELECT DISTINCT product_id FROM product_barcodes
        WHERE organization_id = $1
          AND normalized_barcode = ANY($2::text[])
          AND product_id <> $3
      `,
      [command.organizationId, normalized, productId],
    );
    if (conflicts.rowCount !== 0) {
      throw new RemoteCommandError("already-exists", "A barcode belongs to another product.");
    }
  }
  await client.query(
    `
      UPDATE product_barcodes
      SET deleted_at = now(), is_primary = false, version = version + 1, updated_at = now()
      WHERE organization_id = $1 AND product_id = $2 AND deleted_at IS NULL
    `,
    [command.organizationId, productId],
  );
  for (let index = 0; index < barcodes.length; index += 1) {
    await client.query(
      `
        INSERT INTO product_barcodes (
          id, organization_id, product_id, barcode, normalized_barcode,
          is_primary, version, created_at, updated_at, deleted_at
        ) VALUES ($1, $2, $3, $4, $5, $6, 0, now(), now(), NULL)
        ON CONFLICT (organization_id, normalized_barcode) DO UPDATE SET
          barcode = EXCLUDED.barcode,
          is_primary = EXCLUDED.is_primary,
          deleted_at = NULL,
          version = product_barcodes.version + 1,
          updated_at = now()
      `,
      [randomUUID(), command.organizationId, productId, barcodes[index], normalized[index], index === 0],
    );
  }
}

async function appendPriceIfChanged(
  client: PoolClient,
  command: AuthorizedCommand,
  productId: string,
): Promise<void> {
  const unitPriceMinor = requiredInteger(command.payload, "unitPriceMinor");
  if (unitPriceMinor < 0) {
    throw new RemoteCommandError("invalid-argument", "The unit price cannot be negative.");
  }
  const scope = requiredString(command.payload, "priceScope");
  const branchId = optionalString(command.payload, "priceBranchId");
  if ((scope === "organization" && branchId !== null) ||
      (scope === "branch" && branchId === null)) {
    throw new RemoteCommandError("invalid-argument", "The price scope and branch do not agree.");
  }
  if (branchId !== null && branchId !== command.branchId) {
    throw new RemoteCommandError("permission-denied", "A price cannot target another branch.");
  }
  const branchScope = branchId ?? "*";
  const latest = await client.query<{unit_price_minor: string}>(
    `
      SELECT unit_price_minor FROM product_prices
      WHERE organization_id = $1 AND product_id = $2 AND branch_scope = $3
      ORDER BY effective_from DESC LIMIT 1
    `,
    [command.organizationId, productId, branchScope],
  );
  if (latest.rowCount === 1 && Number(latest.rows[0].unit_price_minor) === unitPriceMinor) return;
  const effectiveFrom = optionalTimestamp(command.payload, "priceEffectiveFrom") ?? new Date();
  await client.query(
    `
      INSERT INTO product_prices (
        id, organization_id, product_id, branch_id, branch_scope,
        unit_price_minor, effective_from, created_by_user_id,
        version, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 0, now(), now())
    `,
    [optionalString(command.payload, "priceId") ?? randomUUID(), command.organizationId, productId, branchId, branchScope, unitPriceMinor, effectiveFrom, command.actorUserId],
  );
}

async function setProductArchived(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const archived = requiredBoolean(command.payload, "archived");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  const result = await client.query(
    `
      UPDATE products SET
        is_active = $3,
        deleted_at = CASE WHEN $3 THEN NULL ELSE now() END,
        version = version + 1,
        updated_at = now()
      WHERE id = $1 AND organization_id = $2 AND version = $4
    `,
    [command.aggregateId, command.organizationId, !archived, expectedVersion],
  );
  if (result.rowCount !== 1) throw new RemoteCommandError("aborted", "The product was changed on another device.");
  return {product: await productPayload(client, command.organizationId, command.aggregateId)};
}

async function createProductPrice(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const productId = requiredString(command.payload, "productId");
  await requireCatalogReference(client, "products", productId, command.organizationId);
  const unitPriceMinor = requiredInteger(command.payload, "unitPriceMinor");
  const branchId = optionalString(command.payload, "branchId");
  if (unitPriceMinor < 0 || (branchId !== null && branchId !== command.branchId)) {
    throw new RemoteCommandError("invalid-argument", "The price value or branch is invalid.");
  }
  const effectiveFrom = optionalTimestamp(command.payload, "effectiveFrom") ?? new Date();
  const inserted = await client.query(
    `
      INSERT INTO product_prices (
        id, organization_id, product_id, branch_id, branch_scope,
        unit_price_minor, effective_from, created_by_user_id,
        version, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 0, now(), now())
      RETURNING version
    `,
    [command.aggregateId, command.organizationId, productId, branchId, branchId ?? "*", unitPriceMinor, effectiveFrom, command.actorUserId],
  );
  return {
    productPrice: {
      id: command.aggregateId,
      productId,
      branchId,
      unitPriceMinor,
      effectiveFrom: effectiveFrom.toISOString(),
      version: inserted.rows[0]?.version ?? 0,
    },
  };
}

async function upsertCategory(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const name = requiredString(command.payload, "name");
  const creating = command.commandType.endsWith(".create");
  const expectedVersion = creating ? null : requiredInteger(command.payload, "expectedVersion");
  const result = creating ?
    await client.query(
      `INSERT INTO categories (id, organization_id, name, normalized_name, created_at, updated_at)
       VALUES ($1, $2, $3, $4, now(), now()) RETURNING id, version`,
      [command.aggregateId, command.organizationId, name, normalizeSearch(name)],
    ) :
    await client.query(
      `UPDATE categories SET name = $3, normalized_name = $4, version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $5 RETURNING id, version`,
      [command.aggregateId, command.organizationId, name, normalizeSearch(name), expectedVersion],
    );
  if (result.rowCount !== 1) throw new RemoteCommandError("aborted", "The category was changed on another device.");
  return {category: result.rows[0]};
}

async function upsertUnit(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const code = requiredString(payload, "code");
  const name = requiredString(payload, "name");
  const abbreviation = requiredString(payload, "abbreviation");
  const allowsFractional = requiredBoolean(payload, "allowsFractional");
  const creating = command.commandType.endsWith(".create");
  const expectedVersion = creating ? null : requiredInteger(payload, "expectedVersion");
  const result = creating ?
    await client.query(
      `INSERT INTO units (id, organization_id, code, name, abbreviation, allows_fractional, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, now(), now()) RETURNING id, version`,
      [command.aggregateId, command.organizationId, normalizeSearch(code), name, abbreviation, allowsFractional],
    ) :
    await client.query(
      `UPDATE units SET code = $3, name = $4, abbreviation = $5, allows_fractional = $6,
       version = version + 1, updated_at = now()
       WHERE id = $1 AND organization_id = $2 AND version = $7 RETURNING id, version`,
      [command.aggregateId, command.organizationId, normalizeSearch(code), name, abbreviation, allowsFractional, expectedVersion],
    );
  if (result.rowCount !== 1) throw new RemoteCommandError("aborted", "The unit was changed on another device.");
  return {unit: result.rows[0]};
}

async function setSimpleArchived(
  client: PoolClient,
  command: AuthorizedCommand,
  table: "categories" | "units",
): Promise<CommandResult> {
  const archived = requiredBoolean(command.payload, "archived");
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  const result = await client.query(
    `UPDATE ${table} SET is_active = $3, deleted_at = CASE WHEN $3 THEN NULL ELSE now() END,
     version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND version = $4 RETURNING id, version, is_active`,
    [command.aggregateId, command.organizationId, !archived, expectedVersion],
  );
  if (result.rowCount !== 1) throw new RemoteCommandError("aborted", `The ${table.slice(0, -1)} was changed on another device.`);
  return {[table.slice(0, -1)]: result.rows[0]};
}

function requireExpectedVersion(
  payload: Record<string, unknown>,
  actualVersion: number,
  entityName: string,
): void {
  const expectedVersion = requiredInteger(payload, "expectedVersion");
  if (expectedVersion !== actualVersion) {
    throw new RemoteCommandError(
      "aborted",
      `The ${entityName} was changed on another device.`,
    );
  }
}

async function requireCatalogReference(
  client: PoolClient,
  table: "units" | "categories" | "tax_categories" | "products",
  id: string,
  organizationId: string,
): Promise<void> {
  const result = await client.query(
    `SELECT id FROM ${table} WHERE id = $1 AND organization_id = $2 AND deleted_at IS NULL`,
    [id, organizationId],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("invalid-argument", `The ${table} reference is invalid.`);
  }
}

async function productPayload(
  client: PoolClient,
  organizationId: string,
  productId: string,
): Promise<Record<string, unknown>> {
  const result = await client.query(
    `
      SELECT id, organization_id, category_id, unit_id, tax_category_id,
             sku, name, description, is_active, version, updated_at, deleted_at
      FROM products WHERE id = $1 AND organization_id = $2
    `,
    [productId, organizationId],
  );
  if (result.rowCount !== 1) throw new RemoteCommandError("not-found", "The product does not exist.");
  const barcodes = await client.query(
    `SELECT id, barcode, is_primary, version, updated_at
     FROM product_barcodes
     WHERE organization_id = $1 AND product_id = $2 AND deleted_at IS NULL
     ORDER BY is_primary DESC, barcode`,
    [organizationId, productId],
  );
  const prices = await client.query(
    `SELECT id, branch_id, unit_price_minor, effective_from, version, updated_at
     FROM product_prices
     WHERE organization_id = $1 AND product_id = $2
     ORDER BY effective_from`,
    [organizationId, productId],
  );
  return {
    ...(result.rows[0] as Record<string, unknown>),
    barcodes: barcodes.rows,
    prices: prices.rows,
  };
}
