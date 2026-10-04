export type UsageScope = keyof typeof defaultUsagePolicies;
export type UsageWindow = {maximumRequests: number; windowSeconds: number};
export type UsagePolicy = {user: UsageWindow; organization?: UsageWindow; enabled: boolean};
const minute = (maximumRequests: number): UsageWindow => ({maximumRequests, windowSeconds: 60});
const hour = (maximumRequests: number): UsageWindow => ({maximumRequests, windowSeconds: 3600});
const day = (maximumRequests: number): UsageWindow => ({maximumRequests, windowSeconds: 86400});

export const defaultUsagePolicies = {
  access_profile: {user: minute(30)},
  // Registration is also a heartbeat during sign-in. Keep it retryable; do not
  // apply a daily installation quota to ordinary device refreshes.
  register_device: {user: minute(10), organization: minute(100)},
  new_device: {user: day(10), organization: day(100)},
  remote_command: {user: minute(120), organization: minute(2000)},
  update_branch: {user: minute(30), organization: minute(300)},
  stock_locations: {user: minute(30), organization: minute(300)},
  administration_snapshot: {user: minute(12), organization: minute(60)},
  pos_bootstrap: {user: minute(60), organization: minute(600)},
  pull_changes: {user: minute(120), organization: minute(2000)},
  staff_invite: {user: hour(10), organization: day(50)},
  accept_invite: {user: hour(10)},
  register_claim: {user: minute(20), organization: minute(100)},
  product_image: {user: hour(20), organization: day(200)},
} satisfies Record<string, Omit<UsagePolicy, "enabled">>;

const optionalScopes: ReadonlySet<string> = new Set([
  "product_image", "staff_invite", "administration_snapshot",
]);

// Operator-only, source-controlled defaults + deployment environment overrides.
// Never accept policies or exemption flags from client request data or role names.
export function loadUsagePolicies(raw = process.env.JCE_USAGE_LIMITS_JSON ?? "{}"):
  Record<UsageScope, UsagePolicy> {
  const overrides: unknown = JSON.parse(raw);
  if (!isObject(overrides)) throw new Error("Usage policy must be an object.");
  for (const scope of Object.keys(overrides)) {
    if (!Object.hasOwn(defaultUsagePolicies, scope)) throw new Error("Unknown usage policy scope.");
  }
  return Object.fromEntries(Object.entries(defaultUsagePolicies).map(([scope, defaults]) => {
    const override = overrides[scope] ?? {};
    if (!isObject(override) || Object.keys(override).some((key) =>
      !["user", "organization", "enabled"].includes(key))) throw new Error("Invalid usage policy.");
    const enabled = override.enabled ?? true;
    if (typeof enabled !== "boolean" || (!enabled && !optionalScopes.has(scope))) {
      throw new Error("Core operation kill switches are prohibited.");
    }
    const organization = "organization" in defaults ? defaults.organization : undefined;
    if (override.organization !== undefined && organization === undefined) {
      throw new Error("This scope has no organization quota.");
    }
    return [scope, {enabled, user: readWindow(override.user, defaults.user),
      organization: organization && readWindow(override.organization, organization)}];
  })) as Record<UsageScope, UsagePolicy>;
}

function readWindow(value: unknown, fallback: UsageWindow): UsageWindow {
  if (value === undefined) return {...fallback};
  if (!isObject(value) || Object.keys(value).some((key) =>
    !["maximumRequests", "windowSeconds"].includes(key))) throw new Error("Invalid usage window.");
  const maximumRequests = value.maximumRequests ?? fallback.maximumRequests;
  const windowSeconds = value.windowSeconds ?? fallback.windowSeconds;
  if (typeof maximumRequests !== "number" || !Number.isSafeInteger(maximumRequests) ||
      maximumRequests < 1 || maximumRequests > 1_000_000 ||
      typeof windowSeconds !== "number" || !Number.isSafeInteger(windowSeconds) ||
      windowSeconds < 1 || windowSeconds > 86400) throw new Error("Invalid usage window.");
  return {maximumRequests, windowSeconds};
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
