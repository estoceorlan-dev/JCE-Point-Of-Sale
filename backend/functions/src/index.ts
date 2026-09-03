import {initializeApp} from "firebase-admin/app";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {defineString} from "firebase-functions/params";

import {
  AccessProfileDeniedError,
  loadAccessProfile,
  registerDeviceForUser,
  updateBranchNameForUser,
} from "./access_profile";
import {withDatabase} from "./database";
import {
  asObject,
  RemoteCommandError,
} from "./remote_commands/command_types";
import {processRemoteCommand} from "./remote_commands/remote_command_service";
import {
  copyProductImage,
  deleteStagingImage,
  findPriorImageFinalization,
  persistProductImageFinalization,
} from "./product_image_finalizer";

initializeApp();

const functionsRegion = defineString("JCE_FUNCTIONS_REGION", {
  default: "asia-southeast1",
});
const databaseInstanceConnectionName = defineString(
  "JCE_DB_INSTANCE_CONNECTION_NAME",
  {description: "Cloud SQL project:region:instance for this environment."},
);
const databaseName = defineString("JCE_DB_NAME", {
  description: "PostgreSQL database for this environment.",
});
const databaseUser = defineString("JCE_DB_USER", {
  description: "IAM PostgreSQL user for this environment.",
});
const runtimeServiceAccount = defineString("JCE_FUNCTIONS_SERVICE_ACCOUNT", {
  description: "Runtime service account for this environment.",
});

export const getMyAccessProfile = onCall(
  {
    region: functionsRegion,
    serviceAccount: runtimeServiceAccount,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (uid === undefined) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    try {
      return await withDatabase(databaseConfig(), (client) =>
        loadAccessProfile(
          client,
          uid,
          typeof request.auth?.token.email === "string"
            ? request.auth.token.email
            : undefined,
        ),
      );
    } catch (error) {
      if (error instanceof AccessProfileDeniedError) {
        throw new HttpsError(
          error.reason === "not-found" ? "not-found" : "permission-denied",
          "No active JCE POS access profile is available.",
        );
      }
      logger.error("Access profile lookup failed.", error);
      throw new HttpsError("internal", "Access profile lookup failed.");
    }
  },
);

export const registerDevice = onCall(
  {
    region: functionsRegion,
    serviceAccount: runtimeServiceAccount,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (uid === undefined) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const deviceId = requiredString(request.data, "deviceId");
    const platform = requiredString(request.data, "platform");
    const organizationId = requiredString(request.data, "organizationId");
    const branchId = requiredString(request.data, "branchId");

    try {
      await withDatabase(databaseConfig(), (client) =>
        registerDeviceForUser(client, {
          firebaseUid: uid,
          deviceId,
          platform,
          organizationId,
          branchId,
        }),
      );
      return {registered: true};
    } catch (error) {
      if (error instanceof AccessProfileDeniedError) {
        throw new HttpsError(
          "permission-denied",
          "The device cannot be registered for this branch.",
        );
      }
      logger.error("Device registration failed.", error);
      throw new HttpsError("internal", "Device registration failed.");
    }
  },
);

export const updateBranchName = onCall(
  {
    region: functionsRegion,
    serviceAccount: runtimeServiceAccount,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (uid === undefined) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const organizationId = requiredString(request.data, "organizationId");
    const branchId = requiredString(request.data, "branchId");
    const name = requiredString(request.data, "name");
    if (name.length < 2 || name.length > 80) {
      throw new HttpsError(
        "invalid-argument",
        "Branch name must contain between 2 and 80 characters.",
      );
    }

    try {
      await withDatabase(databaseConfig(), (client) =>
        updateBranchNameForUser(client, {
          firebaseUid: uid,
          organizationId,
          branchId,
          name,
        }),
      );
      return {updated: true};
    } catch (error) {
      if (error instanceof AccessProfileDeniedError) {
        throw new HttpsError(
          "permission-denied",
          "The branch name cannot be changed by this account.",
        );
      }
      logger.error("Branch name update failed.", error);
      throw new HttpsError("internal", "Branch name update failed.");
    }
  },
);

export const applyRemoteCommand = onCall(
  {
    region: functionsRegion,
    serviceAccount: runtimeServiceAccount,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (uid === undefined) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    try {
      const data = asObject(request.data, "data");
      const payload = asObject(data.payload, "payload");
      return await withDatabase(databaseConfig(), (client) =>
        processRemoteCommand(client, {
          firebaseUid: uid,
          operationId: requiredString(data, "operationId"),
          organizationId: requiredString(data, "organizationId"),
          branchId: requiredString(data, "branchId"),
          commandType: requiredString(data, "commandType"),
          aggregateType: requiredString(data, "aggregateType"),
          aggregateId: requiredString(data, "aggregateId"),
          deviceId: optionalString(data, "deviceId"),
          payload,
        }),
      );
    } catch (error) {
      if (error instanceof RemoteCommandError) {
        throw new HttpsError(error.code, error.message);
      }
      logger.error("Remote command failed.", error);
      throw new HttpsError("internal", "The remote command failed.");
    }
  },
);

export const finalizeProductImage = onCall(
  {
    region: functionsRegion,
    serviceAccount: runtimeServiceAccount,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (uid === undefined) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    try {
      const data = asObject(request.data, "data");
      const imageId = requiredString(data, "imageId");
      const input = {
        firebaseUid: uid,
        operationId: requiredString(data, "operationId"),
        organizationId: requiredString(data, "organizationId"),
        branchId: requiredString(data, "branchId"),
        commandType: "product_image.finalize",
        aggregateType: "product_image",
        aggregateId: imageId,
        productId: requiredString(data, "productId"),
        stagingPath: requiredString(data, "stagingPath"),
        payload: {},
      };
      const prior = await withDatabase(databaseConfig(), (client) =>
        findPriorImageFinalization(client, input),
      );
      if (prior !== null) return prior;
      const uploaded = await copyProductImage(input);
      const result = await withDatabase(databaseConfig(), (client) =>
        persistProductImageFinalization(client, input, uploaded),
      );
      await deleteStagingImage(input.stagingPath);
      return result;
    } catch (error) {
      if (error instanceof RemoteCommandError) {
        throw new HttpsError(error.code, error.message);
      }
      logger.error("Product image finalization failed.", error);
      throw new HttpsError("internal", "The product image could not be finalized.");
    }
  },
);

function databaseConfig() {
  return {
    instanceConnectionName: databaseInstanceConnectionName.value(),
    database: databaseName.value(),
    user: databaseUser.value(),
  };
}

function requiredString(
  value: unknown,
  key: string,
): string {
  if (typeof value !== "object" || value === null) {
    throw new HttpsError("invalid-argument", "Request data is required.");
  }
  const candidate = (value as Record<string, unknown>)[key];
  if (typeof candidate !== "string" || candidate.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${key} is required.`);
  }
  return candidate.trim();
}

function optionalString(value: unknown, key: string): string | null {
  if (typeof value !== "object" || value === null) return null;
  const candidate = (value as Record<string, unknown>)[key];
  if (candidate === undefined || candidate === null) return null;
  if (typeof candidate !== "string") {
    throw new HttpsError("invalid-argument", `${key} must be a string.`);
  }
  const normalized = candidate.trim();
  return normalized.length === 0 ? null : normalized;
}
