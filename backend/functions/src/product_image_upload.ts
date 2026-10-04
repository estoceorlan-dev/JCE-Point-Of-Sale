import {createHash} from "node:crypto";
import {getStorage} from "firebase-admin/storage";
import {HttpsError} from "firebase-functions/v2/https";
import {PoolClient} from "pg";
import {enforceRateLimit, RateLimitExceededError} from "./api_rate_limiter";
import {ProductImageFinalization} from "./product_image_finalizer";

export const maximumImageBytes = 5 * 1024 * 1024;

export function decodeImageUpload(value: unknown, contentType: unknown): Buffer {
  if (typeof value !== "string" || value.length === 0 ||
      value.length > 4 * Math.ceil(maximumImageBytes / 3) || value.length % 4 !== 0) {
    throw new HttpsError("invalid-argument", "The image encoding or size is invalid.");
  }
  const bytes = Buffer.from(value, "base64");
  if (bytes.toString("base64") !== value) {
    throw new HttpsError("invalid-argument", "The image encoding is invalid.");
  }
  const isPng = bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const isJpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  const isWebp = bytes.length >= 12 && bytes.toString("ascii", 0, 4) === "RIFF" &&
    bytes.toString("ascii", 8, 12) === "WEBP";
  if (bytes.length === 0 || bytes.length > maximumImageBytes ||
      !(contentType === "image/png" && isPng || contentType === "image/jpeg" && isJpeg ||
        contentType === "image/webp" && isWebp)) {
    throw new HttpsError("invalid-argument", "The image format or size is invalid.");
  }
  return bytes;
}

export async function reserveImageBytes(client: PoolClient, organizationId: string, bytes: number) {
  const configured = process.env.JCE_IMAGE_BYTES_PER_DAY ?? String(100 * 1024 * 1024);
  const daily = Number(configured);
  if (!Number.isSafeInteger(daily) || daily < 1 || daily > 1_000_000_000) {
    throw new Error("Invalid server image-byte policy.");
  }
  // Charge attempts, including retried uploads. This bounds bytes before any
  // Storage write even when many requests arrive concurrently.
  if (bytes > daily) throw new RateLimitExceededError(86400);
  await enforceRateLimit(client, {firebaseUid: JSON.stringify(["organization", organizationId]),
    scope: "image_bytes_daily", maximumRequests: daily, windowSeconds: 86400, units: bytes});
}

export async function stageAuthorizedImage(input: ProductImageFinalization,
  bytes: Buffer, contentType: string, storage = getStorage()): Promise<void> {
  const file = storage.bucket().file(input.stagingPath);
  const digest = createHash("sha256").update(bytes).digest("hex");
  try {
    await file.save(bytes, {resumable: false, preconditionOpts: {ifGenerationMatch: 0},
      metadata: {contentType, cacheControl: "private, no-store", metadata: {
        sha256: digest, productId: input.productId, organizationId: input.organizationId,
      }}});
  } catch (error) {
    if (Number((error as {code?: unknown}).code) !== 412) throw error;
    const [metadata] = await file.getMetadata();
    if (metadata.metadata?.sha256 !== digest || metadata.metadata?.productId !== input.productId ||
        metadata.metadata?.organizationId !== input.organizationId) {
      throw new HttpsError("already-exists", "This image ID has different upload content.");
    }
  }
}
