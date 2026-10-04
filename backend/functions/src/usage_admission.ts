import {PoolClient} from "pg";
import {enforceRateLimit} from "./api_rate_limiter";
import {UsagePolicy, UsageScope} from "./usage_policy";

export class OptionalFeatureDisabledError extends Error {}

export async function enforceUsageAdmission(client: PoolClient, input: {
  firebaseUid: string; scope: UsageScope; policy: UsagePolicy;
  organizationId?: string; branchId?: string;
}): Promise<void> {
  const {policy, scope, firebaseUid} = input;
  // Global UID bucket cannot be bypassed by rotating device or organization IDs.
  await enforceRateLimit(client, {firebaseUid: JSON.stringify(["user", firebaseUid]),
    scope: `${scope}_u_${policy.user.windowSeconds}`, ...policy.user});
  if (!policy.enabled) throw new OptionalFeatureDisabledError(scope);
  if (!policy.organization || !input.organizationId) return;
  // Check membership before charging a shared bucket. A foreign caller must not
  // exhaust another organization's quota by supplying its ID.
  const membership = await client.query(
    `SELECT 1 FROM app_users au
     JOIN organizations o ON o.id = au.organization_id
       AND o.is_active = true AND o.deleted_at IS NULL
     JOIN user_role_assignments ura ON ura.user_id = au.id
       AND ura.organization_id = au.organization_id AND ura.revoked_at IS NULL
     JOIN roles r ON r.id = ura.role_id AND r.organization_id = au.organization_id
       AND r.is_active = true AND r.deleted_at IS NULL
     WHERE au.firebase_uid = $1 AND au.organization_id = $2
       AND au.status = 'active' AND au.deleted_at IS NULL
       AND ($3::text IS NULL OR (ura.branch_id IS NULL OR ura.branch_id = $3))
       AND ($3::text IS NULL OR EXISTS (SELECT 1 FROM branches b
         WHERE b.id = $3 AND b.organization_id = o.id
           AND b.is_active = true AND b.deleted_at IS NULL))
     LIMIT 1`, [firebaseUid, input.organizationId, input.branchId ?? null]);
  // The endpoint still performs its exact permission/record authorization. No
  // membership here is not an authorization success or a role-based exemption.
  if (membership.rowCount !== 1) return;
  await enforceRateLimit(client, {
    firebaseUid: JSON.stringify(["organization", input.organizationId]),
    scope: `${scope}_o_${policy.organization.windowSeconds}`, ...policy.organization,
  });
}
