import 'package:cloud_functions/cloud_functions.dart';

class PosBootstrapPage {
  const PosBootstrapPage({
    required this.snapshotToken,
    required this.collection,
    required this.cursor,
    required this.nextCursor,
    required this.watermark,
    required this.checksum,
    required this.rows,
    required this.complete,
  });

  final String snapshotToken;
  final String collection;
  final String cursor;
  final String? nextCursor;
  final int watermark;
  final String checksum;
  final List<Map<String, Object?>> rows;
  final bool complete;
}

abstract interface class PosBootstrapRemoteDataSource {
  Future<PosBootstrapPage> fetchPage({
    required String organizationId,
    required String branchId,
    required String collection,
    String? snapshotToken,
    String? cursor,
    int pageSize = 250,
  });
}

class CloudFunctionsPosBootstrapRemoteDataSource
    implements PosBootstrapRemoteDataSource {
  const CloudFunctionsPosBootstrapRemoteDataSource({
    required FirebaseFunctions functions,
    required String functionName,
  }) : _functions = functions,
       _functionName = functionName;

  final FirebaseFunctions _functions;
  final String _functionName;

  @override
  Future<PosBootstrapPage> fetchPage({
    required String organizationId,
    required String branchId,
    required String collection,
    String? snapshotToken,
    String? cursor,
    int pageSize = 250,
  }) async {
    final response = await _functions.httpsCallable(_functionName).call({
      'organizationId': organizationId,
      'branchId': branchId,
      'collection': collection,
      'snapshotToken': snapshotToken,
      'cursor': cursor,
      'pageSize': pageSize,
    });
    if (response.data is! Map) {
      throw const FormatException('Invalid POS bootstrap response.');
    }
    final value = Map<String, Object?>.from(response.data as Map);
    final rawRows = value['rows'];
    if (rawRows is! List) {
      throw const FormatException('Invalid POS bootstrap rows.');
    }
    return PosBootstrapPage(
      snapshotToken: _requiredString(value, 'snapshotToken'),
      collection: _requiredString(value, 'collection'),
      cursor: value['cursor']?.toString() ?? '',
      nextCursor: value['nextCursor']?.toString(),
      watermark: (value['watermark'] as num?)?.toInt() ?? 0,
      checksum: _requiredString(value, 'checksum'),
      rows: rawRows
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList(growable: false),
      complete: value['complete'] == true,
    );
  }
}

String _requiredString(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! String || result.isEmpty) {
    throw FormatException('POS bootstrap $key is missing.');
  }
  return result;
}
