import 'package:cloud_functions/cloud_functions.dart';
import 'remote_api_exception.dart';

/// Compatibility boundary until the legacy transport is retired.
Object normalizeLegacySyncError(Object error) =>
    error is FirebaseFunctionsException
    ? RemoteApiException(
        error.code,
        message: error.message,
        details: error.details,
      )
    : error;
