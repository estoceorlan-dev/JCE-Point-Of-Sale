const {randomUUID} = require("node:crypto");
const {Client} = require("pg");

function requiredEnvironment(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

async function requireProvisioningScope(
  client,
  {organizationId, roleId, branchId},
) {
  const organization = await client.query(
    `
      SELECT id
      FROM organizations
      WHERE id = $1
        AND is_active = true
        AND deleted_at IS NULL
    `,
    [organizationId],
  );
  if (organization.rowCount !== 1) {
    throw new Error("The organization is missing or inactive.");
  }

  const role = await client.query(
    `
      SELECT id
      FROM roles
      WHERE id = $1
        AND organization_id = $2
        AND is_active = true
        AND deleted_at IS NULL
    `,
    [roleId, organizationId],
  );
  if (role.rowCount !== 1) {
    throw new Error("The role is missing, inactive, or belongs to another organization.");
  }

  if (branchId === null) {
    return;
  }
  const branch = await client.query(
    `
      SELECT id
      FROM branches
      WHERE id = $1
        AND organization_id = $2
        AND is_active = true
        AND deleted_at IS NULL
    `,
    [branchId, organizationId],
  );
  if (branch.rowCount !== 1) {
    throw new Error("The branch is missing, inactive, or belongs to another organization.");
  }
}

async function resolveUserId(
  client,
  {organizationId, firebaseUid, email, requestedUserId},
) {
  const matches = await client.query(
    `
      SELECT id
      FROM app_users
      WHERE organization_id = $1
        AND (firebase_uid = $2 OR lower(email) = lower($3))
    `,
    [organizationId, firebaseUid, email],
  );
  const matchingIds = [...new Set(matches.rows.map((row) => row.id))];
  if (matchingIds.length > 1) {
    throw new Error(
      "The Firebase UID and email belong to different application users.",
    );
  }
  if (
    requestedUserId !== null &&
    matchingIds.length === 1 &&
    requestedUserId !== matchingIds[0]
  ) {
    throw new Error("JCE_ACCESS_USER_ID does not match the existing user.");
  }
  return matchingIds[0] ?? requestedUserId ?? randomUUID();
}

async function upsertUser(
  client,
  {userId, organizationId, firebaseUid, email, displayName},
) {
  const result = await client.query(
    `
      INSERT INTO app_users (
        id,
        organization_id,
        firebase_uid,
        email,
        display_name,
        status,
        created_at,
        updated_at,
        deleted_at
      )
      VALUES ($1, $2, $3, $4, $5, 'active', now(), now(), NULL)
      ON CONFLICT (id) DO UPDATE SET
        firebase_uid = EXCLUDED.firebase_uid,
        email = EXCLUDED.email,
        display_name = EXCLUDED.display_name,
        status = 'active',
        updated_at = now(),
        deleted_at = NULL
      WHERE app_users.organization_id = EXCLUDED.organization_id
      RETURNING id
    `,
    [userId, organizationId, firebaseUid, email, displayName],
  );
  if (result.rowCount !== 1) {
    throw new Error("The application user ID belongs to another organization.");
  }
}

async function assignRole(
  client,
  {organizationId, branchId, userId, roleId},
) {
  const existing = await client.query(
    `
      SELECT id
      FROM user_role_assignments
      WHERE organization_id = $1
        AND user_id = $2
        AND role_id = $3
        AND branch_id IS NOT DISTINCT FROM $4::text
      ORDER BY assigned_at DESC, id
      LIMIT 1
    `,
    [organizationId, userId, roleId, branchId],
  );

  if (existing.rowCount === 1) {
    await client.query(
      `
        UPDATE user_role_assignments
        SET revoked_at = NULL,
            assigned_at = now()
        WHERE id = $1
      `,
      [existing.rows[0].id],
    );
    return;
  }

  await client.query(
    `
      INSERT INTO user_role_assignments (
        id,
        organization_id,
        branch_id,
        user_id,
        role_id,
        assigned_at,
        revoked_at
      )
      VALUES ($1, $2, $3, $4, $5, now(), NULL)
    `,
    [randomUUID(), organizationId, branchId, userId, roleId],
  );
}

async function main() {
  const input = {
    connectionString: requiredEnvironment("JCE_DATABASE_URL"),
    firebaseUid: requiredEnvironment("JCE_ACCESS_FIREBASE_UID"),
    email: requiredEnvironment("JCE_ACCESS_EMAIL").toLowerCase(),
    displayName: requiredEnvironment("JCE_ACCESS_DISPLAY_NAME"),
    organizationId: requiredEnvironment("JCE_ACCESS_ORGANIZATION_ID"),
    roleId: requiredEnvironment("JCE_ACCESS_ROLE_ID"),
    branchId: process.env.JCE_ACCESS_BRANCH_ID?.trim() || null,
    requestedUserId: process.env.JCE_ACCESS_USER_ID?.trim() || null,
  };

  const client = new Client({connectionString: input.connectionString});
  await client.connect();
  try {
    await client.query("BEGIN");
    await requireProvisioningScope(client, input);
    const userId = await resolveUserId(client, input);
    await upsertUser(client, {...input, userId});
    await assignRole(client, {...input, userId});
    await client.query("COMMIT");
    console.log(`Access provisioned for application user ${userId}.`);
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
