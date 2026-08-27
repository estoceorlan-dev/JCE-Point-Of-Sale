import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import '../database/app_database.dart';

abstract interface class RemoteCommandDataSource {
  Future<RemoteCommandResult> execute(
    SyncOutboxEntry command, {
    Map<String, Object?>? payloadOverride,
  });
}

final class CloudFunctionsRemoteCommandDataSource
    implements RemoteCommandDataSource {
  const CloudFunctionsRemoteCommandDataSource({
    required FirebaseFunctions functions,
    required String functionName,
    required String deviceRegistrationFunctionName,
  }) : _functions = functions,
       _functionName = functionName,
       _deviceRegistrationFunctionName = deviceRegistrationFunctionName;

  final FirebaseFunctions _functions;
  final String _functionName;
  final String _deviceRegistrationFunctionName;

  @override
  Future<RemoteCommandResult> execute(
    SyncOutboxEntry command, {
    Map<String, Object?>? payloadOverride,
  }) async {
    final payload = payloadOverride ?? jsonDecode(command.payloadJson);
    if (payload is! Map) {
      throw const FormatException('Outbox payload must be a JSON object.');
    }

    if (command.commandType == 'device.register') {
      await _functions
          .httpsCallable(_deviceRegistrationFunctionName)
          .call<Object?>(payload);
      return RemoteCommandResult(
        operationId: command.operationId,
        duplicate: false,
        result: const {'registered': true},
      );
    }
    final response = await _functions
        .httpsCallable(_functionName)
        .call<Object?>(<String, Object?>{
          'operationId': command.operationId,
          'organizationId': command.organizationId,
          'branchId': command.branchId,
          'commandType': command.commandType,
          'aggregateType': command.aggregateType,
          'aggregateId': command.aggregateId,
          'payload': payload.map(
            (key, value) => MapEntry(key.toString(), value as Object?),
          ),
        });
    final root = _asStringMap(response.data);
    final result = _asStringMap(root?['result']);
    if (root == null || result == null) {
      throw const FormatException('Remote command returned an invalid result.');
    }
    return RemoteCommandResult(
      operationId: _requiredString(root, 'operationId'),
      duplicate: root['duplicate'] == true,
      result: result,
    );
  }
}

class RemoteCommandResult {
  const RemoteCommandResult({
    required this.operationId,
    required this.duplicate,
    required this.result,
  });

  final String operationId;
  final bool duplicate;
  final Map<String, Object?> result;
}

Map<String, Object?>? _asStringMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredString(Map<String, Object?> value, String key) {
  final result = value[key]?.toString().trim();
  if (result == null || result.isEmpty) {
    throw FormatException('Remote command response is missing $key.');
  }
  return result;
}
