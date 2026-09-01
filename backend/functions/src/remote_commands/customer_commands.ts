import {PoolClient} from "pg";

import {
  AuthorizedCommand,
  CommandResult,
  RemoteCommandError,
  asObject,
  normalizeSearch,
  optionalString,
  optionalTimestamp,
  requiredArray,
  requiredBoolean,
  requiredInteger,
  requiredString,
} from "./command_types";

type CustomerRow = {
  id: string;
  display_name: string;
  email: string | null;
  normalized_email: string | null;
  phone: string | null;
  normalized_phone: string | null;
  status: string;
  version: number;
};

type LoyaltyRow = {
  id: string;
  customer_id: string;
  status: string;
  points_balance: string;
  lifetime_earned_points: string;
  lifetime_redeemed_points: string;
  version: number;
};

type AddressInput = {
  id: string;
  label: string;
  recipientName: string | null;
  lineOne: string;
  lineTwo: string | null;
  city: string;
  province: string | null;
  postalCode: string | null;
  countryCode: string;
  isPrimary: boolean;
};

export async function applyCustomerCommand(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  switch (command.commandType) {
  case "customer.create":
    return createCustomer(client, command);
  case "customer.update":
    return updateCustomer(client, command);
  case "customer.archive":
    return setCustomerStatus(client, command, "active", "archived");
  case "customer.restore":
    return setCustomerStatus(client, command, "archived", "active");
  case "customer.anonymize":
    return anonymizeCustomer(client, command);
  case "customer.merge":
    return mergeCustomers(client, command);
  case "customer.note.add":
    return addCustomerNote(client, command);
  case "loyalty.adjust":
    return adjustLoyalty(client, command);
  default:
    throw new RemoteCommandError(
      "invalid-argument",
      `Unsupported customer command: ${command.commandType}.`,
    );
  }
}

async function createCustomer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const payload = command.payload;
  const id = requireMatchingCustomerId(command);
  const displayName = validateName(payload);
  const email = normalizeEmail(optionalString(payload, "email"));
  const phone = normalizePhone(optionalString(payload, "phone"));
  await rejectDuplicateContact(client, command, email, phone, null);
  const birthDate = optionalTimestamp(payload, "birthDate");
  const addresses = parseAddresses(payload);
  await client.query(
    `INSERT INTO customers (
       id, organization_id, customer_number, display_name, normalized_name,
       email, normalized_email, phone, normalized_phone, birth_date,
       marketing_consent, status, version, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
               'active', 0, now(), now())`,
    [
      id,
      command.organizationId,
      requiredString(payload, "customerNumber"),
      displayName,
      normalizeSearch(displayName),
      optionalString(payload, "email"),
      email,
      optionalString(payload, "phone"),
      phone,
      birthDate,
      requiredBoolean(payload, "marketingConsent"),
    ],
  );
  await replaceAddresses(client, command.organizationId, id, addresses);
  const accountId = optionalString(payload, "loyaltyAccountId");
  if (accountId !== null) {
    await insertLoyaltyAccount(
      client,
      command.organizationId,
      id,
      accountId,
    );
  }
  return customerResult(client, command, id);
}

async function updateCustomer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = requireMatchingCustomerId(command);
  const customer = await requireCustomer(client, command, id);
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (customer.version !== expectedVersion ||
      !["active", "archived"].includes(customer.status)) {
    throw changedCustomer();
  }
  const displayName = validateName(command.payload);
  const email = normalizeEmail(optionalString(command.payload, "email"));
  const phone = normalizePhone(optionalString(command.payload, "phone"));
  await rejectDuplicateContact(client, command, email, phone, id);
  const addresses = parseAddresses(command.payload);
  const changed = await client.query(
    `UPDATE customers SET display_name = $4, normalized_name = $5,
       email = $6, normalized_email = $7, phone = $8,
       normalized_phone = $9, birth_date = $10, marketing_consent = $11,
       version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND version = $3`,
    [
      id,
      command.organizationId,
      expectedVersion,
      displayName,
      normalizeSearch(displayName),
      optionalString(command.payload, "email"),
      email,
      optionalString(command.payload, "phone"),
      phone,
      optionalTimestamp(command.payload, "birthDate"),
      requiredBoolean(command.payload, "marketingConsent"),
    ],
  );
  if (changed.rowCount !== 1) throw changedCustomer();
  await replaceAddresses(client, command.organizationId, id, addresses);
  if (command.payload.enableLoyalty === true) {
    await ensureLoyaltyAccount(
      client,
      command.organizationId,
      id,
      requiredString(command.payload, "loyaltyAccountId"),
    );
  }
  return customerResult(client, command, id);
}

async function setCustomerStatus(
  client: PoolClient,
  command: AuthorizedCommand,
  expectedStatus: string,
  nextStatus: string,
): Promise<CommandResult> {
  const id = requireMatchingCustomerId(command);
  const customer = await requireCustomer(client, command, id);
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  if (customer.version !== expectedVersion || customer.status !== expectedStatus) {
    throw changedCustomer();
  }
  await client.query(
    `UPDATE customers SET status = $4,
       archived_at = CASE WHEN $4 = 'archived' THEN now() ELSE NULL END,
       version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND version = $3`,
    [id, command.organizationId, expectedVersion, nextStatus],
  );
  return customerResult(client, command, id);
}

async function anonymizeCustomer(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const id = requireMatchingCustomerId(command);
  const customer = await requireCustomer(client, command, id);
  const expectedVersion = requiredInteger(command.payload, "expectedVersion");
  const reason = requiredString(command.payload, "reason");
  if (reason.length < 5 || customer.version !== expectedVersion ||
      !["active", "archived"].includes(customer.status)) {
    throw changedCustomer();
  }
  const number = await client.query<{customer_number: string}>(
    "SELECT customer_number FROM customers WHERE id = $1",
    [id],
  );
  const anonymizedName = `Anonymized ${number.rows[0].customer_number}`;
  await client.query(
    `UPDATE customers SET display_name = $4, normalized_name = $5,
       email = NULL, normalized_email = NULL, phone = NULL,
       normalized_phone = NULL, birth_date = NULL, marketing_consent = false,
       status = 'anonymized', archived_at = NULL, anonymized_at = now(),
       version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND version = $3`,
    [id, command.organizationId, expectedVersion, anonymizedName,
      normalizeSearch(anonymizedName)],
  );
  await client.query(
    `UPDATE customer_addresses SET recipient_name = NULL,
       line_one = '[anonymized]', line_two = NULL, city = '[anonymized]',
       province = NULL, postal_code = NULL, deleted_at = now(), updated_at = now()
     WHERE customer_id = $1 AND organization_id = $2`,
    [id, command.organizationId],
  );
  await client.query(
    `UPDATE customer_notes SET body = '[anonymized]', deleted_at = now(),
       updated_at = now() WHERE customer_id = $1 AND organization_id = $2`,
    [id, command.organizationId],
  );
  await client.query(
    `UPDATE loyalty_accounts SET status = 'closed', closed_at = now(),
       version = version + 1, updated_at = now()
     WHERE customer_id = $1 AND organization_id = $2`,
    [id, command.organizationId],
  );
  return customerResult(client, command, id);
}

async function mergeCustomers(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const sourceId = requireMatchingCustomerId(command);
  const targetId = requiredString(command.payload, "targetCustomerId");
  if (sourceId === targetId) {
    throw new RemoteCommandError("invalid-argument", "A customer cannot be merged into itself.");
  }
  const locked = await client.query<CustomerRow>(
    `SELECT id, display_name, email, normalized_email, phone, normalized_phone,
            status, version
     FROM customers WHERE organization_id = $1 AND id = ANY($2::text[])
     ORDER BY id FOR UPDATE`,
    [command.organizationId, [sourceId, targetId]],
  );
  const source = locked.rows.find((row) => row.id === sourceId);
  const target = locked.rows.find((row) => row.id === targetId);
  if (source === undefined || target === undefined ||
      source.status !== "active" || target.status !== "active" ||
      source.version !== requiredInteger(command.payload, "sourceExpectedVersion") ||
      target.version !== requiredInteger(command.payload, "targetExpectedVersion")) {
    throw changedCustomer();
  }
  await client.query(
    `UPDATE customer_addresses SET customer_id = $2, version = version + 1,
       updated_at = now() WHERE customer_id = $1 AND organization_id = $3`,
    [sourceId, targetId, command.organizationId],
  );
  await client.query(
    `UPDATE customer_notes SET customer_id = $2, updated_at = now()
     WHERE customer_id = $1 AND organization_id = $3`,
    [sourceId, targetId, command.organizationId],
  );
  await client.query(
    `UPDATE sales SET customer_id = $2, updated_at = now()
     WHERE customer_id = $1 AND organization_id = $3`,
    [sourceId, targetId, command.organizationId],
  );
  await mergeLoyalty(client, command, sourceId, targetId);
  await client.query(
    `UPDATE customers SET email = COALESCE(email, $4),
       normalized_email = COALESCE(normalized_email, $5),
       phone = COALESCE(phone, $6), normalized_phone = COALESCE(normalized_phone, $7),
       version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND version = $3`,
    [targetId, command.organizationId, target.version, source.email,
      source.normalized_email, source.phone, source.normalized_phone],
  );
  await client.query(
    `UPDATE customers SET status = 'merged', merged_into_customer_id = $4,
       marketing_consent = false, archived_at = now(),
       version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND version = $3`,
    [sourceId, command.organizationId, source.version, targetId],
  );
  return {
    ...(await customerResult(client, command, sourceId)),
    target: await customerResult(client, command, targetId),
  };
}

async function addCustomerNote(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const customerId = requireMatchingCustomerId(command);
  const customer = await requireCustomer(client, command, customerId);
  const body = requiredString(command.payload, "body");
  if (body.length > 2000 || ["merged", "anonymized"].includes(customer.status)) {
    throw new RemoteCommandError("failed-precondition", "The customer note is not valid.");
  }
  await client.query(
    `INSERT INTO customer_notes (
       id, organization_id, branch_id, customer_id, body,
       created_by_user_id, created_at, updated_at
     ) VALUES ($1, $2, $3, $4, $5, $6, now(), now())`,
    [requiredString(command.payload, "noteId"), command.organizationId,
      command.branchId, customerId, body, command.actorUserId],
  );
  return customerResult(client, command, customerId);
}

async function adjustLoyalty(
  client: PoolClient,
  command: AuthorizedCommand,
): Promise<CommandResult> {
  const customerId = requiredString(command.payload, "customerId");
  if (customerId !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Loyalty customer IDs do not match.");
  }
  const customer = await requireCustomer(client, command, customerId);
  const delta = requiredInteger(command.payload, "pointsDelta");
  const reason = requiredString(command.payload, "reason");
  if (customer.status !== "active" || delta === 0 || reason.length < 3) {
    throw new RemoteCommandError("failed-precondition", "The loyalty adjustment is not valid.");
  }
  const account = await ensureLoyaltyAccount(
    client,
    command.organizationId,
    customerId,
    requiredString(command.payload, "accountId"),
  );
  if (account.status !== "active") {
    throw new RemoteCommandError("failed-precondition", "The loyalty account is not active.");
  }
  const balance = Number(account.points_balance) + delta;
  if (balance < 0) {
    throw new RemoteCommandError("failed-precondition", "The loyalty balance cannot be negative.");
  }
  const changed = await client.query(
    `UPDATE loyalty_accounts SET points_balance = $3,
       version = version + 1, updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND version = $4`,
    [account.id, command.organizationId, balance, account.version],
  );
  if (changed.rowCount !== 1) {
    throw new RemoteCommandError("aborted", "The loyalty balance changed.");
  }
  await client.query(
    `INSERT INTO loyalty_ledger_entries (
       id, organization_id, branch_id, account_id, operation_id, entry_type,
       points_delta, balance_after, reason, reference_type, reference_id,
       created_by_user_id, occurred_at, created_at
     ) VALUES ($1, $2, $3, $4, $5, 'adjustment', $6, $7, $8,
               'manual_adjustment', $5, $9, $10, now())`,
    [
      `${command.operationId}:entry`,
      command.organizationId,
      command.branchId,
      account.id,
      command.operationId,
      delta,
      balance,
      reason,
      command.actorUserId,
      optionalTimestamp(command.payload, "occurredAt") ?? new Date(),
    ],
  );
  return customerResult(client, command, customerId);
}

async function mergeLoyalty(
  client: PoolClient,
  command: AuthorizedCommand,
  sourceCustomerId: string,
  targetCustomerId: string,
): Promise<void> {
  const accounts = await client.query<LoyaltyRow>(
    `SELECT id, customer_id, status, points_balance, lifetime_earned_points,
            lifetime_redeemed_points, version
     FROM loyalty_accounts WHERE organization_id = $1
       AND customer_id = ANY($2::text[]) ORDER BY id FOR UPDATE`,
    [command.organizationId, [sourceCustomerId, targetCustomerId]],
  );
  const source = accounts.rows.find((row) => row.customer_id === sourceCustomerId);
  const target = accounts.rows.find((row) => row.customer_id === targetCustomerId);
  if (source === undefined) return;
  if (target === undefined) {
    await client.query(
      `UPDATE loyalty_accounts SET customer_id = $2, version = version + 1,
       updated_at = now() WHERE id = $1`,
      [source.id, targetCustomerId],
    );
    return;
  }
  const points = Number(source.points_balance);
  if (points > 0) {
    await insertMergeEntry(client, command, source.id, `${command.operationId}:merge-out`,
      "merge_out", -points, 0, targetCustomerId);
    await insertMergeEntry(client, command, target.id, `${command.operationId}:merge-in`,
      "merge_in", points, Number(target.points_balance) + points, sourceCustomerId);
  }
  await client.query(
    `UPDATE loyalty_accounts SET status = 'merged', points_balance = 0,
       closed_at = now(), version = version + 1, updated_at = now() WHERE id = $1`,
    [source.id],
  );
  await client.query(
    `UPDATE loyalty_accounts SET points_balance = points_balance + $2,
       version = version + 1, updated_at = now() WHERE id = $1`,
    [target.id, points],
  );
}

async function insertMergeEntry(
  client: PoolClient,
  command: AuthorizedCommand,
  accountId: string,
  operationId: string,
  type: "merge_in" | "merge_out",
  delta: number,
  balance: number,
  otherCustomerId: string,
): Promise<void> {
  await client.query(
    `INSERT INTO loyalty_ledger_entries (
       id, organization_id, branch_id, account_id, operation_id, entry_type,
       points_delta, balance_after, reason, reference_type, reference_id,
       created_by_user_id, occurred_at, created_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9,
               'customer_merge', $10, $11, now(), now())`,
    [`${operationId}:entry`, command.organizationId, command.branchId,
      accountId, operationId, type, delta, balance,
      type === "merge_in" ? "Merged customer loyalty credit" :
        "Transferred loyalty balance during merge",
      otherCustomerId, command.actorUserId],
  );
}

async function replaceAddresses(
  client: PoolClient,
  organizationId: string,
  customerId: string,
  addresses: AddressInput[],
): Promise<void> {
  await client.query(
    `UPDATE customer_addresses SET deleted_at = now(), updated_at = now()
     WHERE organization_id = $1 AND customer_id = $2 AND deleted_at IS NULL`,
    [organizationId, customerId],
  );
  for (const address of addresses) {
    await client.query(
      `INSERT INTO customer_addresses (
         id, organization_id, customer_id, label, recipient_name,
         line_one, line_two, city, province, postal_code, country_code,
         is_primary, version, created_at, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
                 $12, 0, now(), now())
       ON CONFLICT (id) DO UPDATE SET
         customer_id = EXCLUDED.customer_id, label = EXCLUDED.label,
         recipient_name = EXCLUDED.recipient_name, line_one = EXCLUDED.line_one,
         line_two = EXCLUDED.line_two, city = EXCLUDED.city,
         province = EXCLUDED.province, postal_code = EXCLUDED.postal_code,
         country_code = EXCLUDED.country_code, is_primary = EXCLUDED.is_primary,
         deleted_at = NULL, version = customer_addresses.version + 1,
         updated_at = now()`,
      [address.id, organizationId, customerId, address.label,
        address.recipientName, address.lineOne, address.lineTwo, address.city,
        address.province, address.postalCode, address.countryCode,
        address.isPrimary],
    );
  }
}

function parseAddresses(payload: Record<string, unknown>): AddressInput[] {
  const addresses = requiredArray(payload, "addresses").map((value, index) => {
    const address = asObject(value, `addresses[${index}]`);
    const countryCode = requiredString(address, "countryCode").toUpperCase();
    if (countryCode.length !== 2) {
      throw new RemoteCommandError("invalid-argument", "Address country code is invalid.");
    }
    return {
      id: requiredString(address, "id"),
      label: requiredString(address, "label"),
      recipientName: optionalString(address, "recipientName"),
      lineOne: requiredString(address, "lineOne"),
      lineTwo: optionalString(address, "lineTwo"),
      city: requiredString(address, "city"),
      province: optionalString(address, "province"),
      postalCode: optionalString(address, "postalCode"),
      countryCode,
      isPrimary: requiredBoolean(address, "isPrimary"),
    };
  });
  if (addresses.filter((address) => address.isPrimary).length > 1) {
    throw new RemoteCommandError("invalid-argument", "Only one address can be primary.");
  }
  return addresses;
}

async function rejectDuplicateContact(
  client: PoolClient,
  command: AuthorizedCommand,
  email: string | null,
  phone: string | null,
  excludingId: string | null,
): Promise<void> {
  if ((email === null && phone === null) ||
      command.payload.allowDuplicateContact === true) return;
  const duplicate = await client.query(
    `SELECT 1 FROM customers WHERE organization_id = $1
       AND status IN ('active', 'archived')
       AND ($2::text IS NULL OR id <> $2)
       AND (($3::text IS NOT NULL AND normalized_email = $3) OR
            ($4::text IS NOT NULL AND normalized_phone = $4)) LIMIT 1`,
    [command.organizationId, excludingId, email, phone],
  );
  if (duplicate.rowCount !== 0) {
    throw new RemoteCommandError(
      "already-exists",
      "Customer contact details already exist. Merge or explicitly allow the duplicate.",
    );
  }
}

async function requireCustomer(
  client: PoolClient,
  command: AuthorizedCommand,
  id: string,
): Promise<CustomerRow> {
  const result = await client.query<CustomerRow>(
    `SELECT id, display_name, email, normalized_email, phone,
            normalized_phone, status, version
     FROM customers WHERE id = $1 AND organization_id = $2 FOR UPDATE`,
    [id, command.organizationId],
  );
  if (result.rowCount !== 1) {
    throw new RemoteCommandError("not-found", "The customer does not exist.");
  }
  return result.rows[0];
}

async function ensureLoyaltyAccount(
  client: PoolClient,
  organizationId: string,
  customerId: string,
  preferredId: string,
): Promise<LoyaltyRow> {
  const existing = await client.query<LoyaltyRow>(
    `SELECT id, customer_id, status, points_balance, lifetime_earned_points,
            lifetime_redeemed_points, version
     FROM loyalty_accounts WHERE organization_id = $1 AND customer_id = $2
     FOR UPDATE`,
    [organizationId, customerId],
  );
  if (existing.rowCount === 1) return existing.rows[0];
  await insertLoyaltyAccount(client, organizationId, customerId, preferredId);
  const created = await client.query<LoyaltyRow>(
    `SELECT id, customer_id, status, points_balance, lifetime_earned_points,
            lifetime_redeemed_points, version
     FROM loyalty_accounts WHERE id = $1`,
    [preferredId],
  );
  return created.rows[0];
}

async function insertLoyaltyAccount(
  client: PoolClient,
  organizationId: string,
  customerId: string,
  accountId: string,
): Promise<void> {
  await client.query(
    `INSERT INTO loyalty_accounts (
       id, organization_id, customer_id, status, points_balance,
       lifetime_earned_points, lifetime_redeemed_points, version,
       created_at, updated_at
     ) VALUES ($1, $2, $3, 'active', 0, 0, 0, 0, now(), now())`,
    [accountId, organizationId, customerId],
  );
}

async function customerResult(
  client: PoolClient,
  command: AuthorizedCommand,
  customerId: string,
): Promise<CommandResult> {
  const customer = await client.query(
    `SELECT id, customer_number AS "customerNumber",
            display_name AS "displayName", email, normalized_email AS "normalizedEmail",
            phone, normalized_phone AS "normalizedPhone", birth_date AS "birthDate",
            marketing_consent AS "marketingConsent", status,
            merged_into_customer_id AS "mergedIntoCustomerId",
            archived_at AS "archivedAt", anonymized_at AS "anonymizedAt",
            version, created_at AS "createdAt", updated_at AS "updatedAt"
     FROM customers WHERE id = $1 AND organization_id = $2`,
    [customerId, command.organizationId],
  );
  const addresses = await client.query(
    `SELECT id, label, recipient_name AS "recipientName", line_one AS "lineOne",
            line_two AS "lineTwo", city, province, postal_code AS "postalCode",
            country_code AS "countryCode", is_primary AS "isPrimary", version,
            created_at AS "createdAt", updated_at AS "updatedAt",
            deleted_at AS "deletedAt"
     FROM customer_addresses WHERE customer_id = $1 AND organization_id = $2
     ORDER BY created_at`,
    [customerId, command.organizationId],
  );
  const notes = command.commandType === "customer.note.add" ?
    await client.query(
      `SELECT id, branch_id AS "branchId", body,
              created_by_user_id AS "createdByUserId",
              created_at AS "createdAt", updated_at AS "updatedAt",
              deleted_at AS "deletedAt"
       FROM customer_notes WHERE customer_id = $1 AND organization_id = $2
         AND branch_id = $3 ORDER BY created_at`,
      [customerId, command.organizationId, command.branchId],
    ) : {rows: []};
  const accounts = await client.query(
    `SELECT id, status, points_balance::text AS "pointsBalance",
            lifetime_earned_points::text AS "lifetimeEarnedPoints",
            lifetime_redeemed_points::text AS "lifetimeRedeemedPoints",
            version, created_at AS "createdAt", updated_at AS "updatedAt",
            closed_at AS "closedAt"
     FROM loyalty_accounts WHERE customer_id = $1 AND organization_id = $2`,
    [customerId, command.organizationId],
  );
  let entries: Record<string, unknown>[] = [];
  if (accounts.rowCount === 1) {
    const ledger = await client.query(
      `SELECT id, branch_id AS "branchId", sale_id AS "saleId",
              operation_id AS "operationId", entry_type AS "entryType",
              points_delta::text AS "pointsDelta",
              balance_after::text AS "balanceAfter", reason,
              reference_type AS "referenceType", reference_id AS "referenceId",
              created_by_user_id AS "createdByUserId",
              occurred_at AS "occurredAt", created_at AS "createdAt"
       FROM loyalty_ledger_entries WHERE account_id = $1 ORDER BY occurred_at`,
      [accounts.rows[0].id],
    );
    entries = ledger.rows.map(numericLoyaltyEntry);
  }
  return {
    customer: customer.rows[0],
    addresses: addresses.rows,
    notes: notes.rows,
    loyaltyAccount: accounts.rowCount === 0 ? null :
      numericLoyaltyAccount(accounts.rows[0]),
    loyaltyEntries: entries,
  };
}

function numericLoyaltyAccount(row: Record<string, unknown>): Record<string, unknown> {
  return {
    ...row,
    pointsBalance: Number(row.pointsBalance),
    lifetimeEarnedPoints: Number(row.lifetimeEarnedPoints),
    lifetimeRedeemedPoints: Number(row.lifetimeRedeemedPoints),
  };
}

function numericLoyaltyEntry(row: Record<string, unknown>): Record<string, unknown> {
  return {
    ...row,
    pointsDelta: Number(row.pointsDelta),
    balanceAfter: Number(row.balanceAfter),
  };
}

function requireMatchingCustomerId(command: AuthorizedCommand): string {
  const id = requiredString(command.payload, "id");
  if (id !== command.aggregateId) {
    throw new RemoteCommandError("invalid-argument", "Customer IDs do not match.");
  }
  return id;
}

function validateName(payload: Record<string, unknown>): string {
  const name = requiredString(payload, "displayName");
  if (name.length < 2) {
    throw new RemoteCommandError("invalid-argument", "Customer name is too short.");
  }
  return name;
}

function normalizeEmail(value: string | null): string | null {
  if (value === null) return null;
  const email = value.toLowerCase();
  if (!email.includes("@") || email.startsWith("@") || email.endsWith("@")) {
    throw new RemoteCommandError("invalid-argument", "Customer email is invalid.");
  }
  return email;
}

function normalizePhone(value: string | null): string | null {
  if (value === null) return null;
  const phone = value.replace(/[^0-9]/g, "");
  if (phone.length < 7) {
    throw new RemoteCommandError("invalid-argument", "Customer phone is invalid.");
  }
  return phone;
}

function changedCustomer(): RemoteCommandError {
  return new RemoteCommandError(
    "failed-precondition",
    "The remote customer changed. Refresh and retry.",
  );
}
