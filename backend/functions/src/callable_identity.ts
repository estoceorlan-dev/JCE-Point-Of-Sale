import {HttpsError, type CallableRequest} from "firebase-functions/v2/https";

export function requireVerifiedUser(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  if (request.auth?.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "A verified email address is required.");
  }
  return uid;
}

// auth_time records credential verification. iat only records token refresh and
// must never authorize a sensitive action as though the user signed in again.
export function requireRecentVerifiedUser(
  request: CallableRequest<unknown>,
  nowSeconds = Math.floor(Date.now() / 1000),
): string {
  const uid = requireVerifiedUser(request);
  const authenticatedAt = request.auth?.token.auth_time;
  if (typeof authenticatedAt !== "number" ||
      !Number.isSafeInteger(authenticatedAt) || authenticatedAt <= 0 ||
      authenticatedAt > nowSeconds || nowSeconds - authenticatedAt > 300) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in again before approving this action.",
      {reason: "recent-authentication-required"},
    );
  }
  return uid;
}
