import '../../features/auth/data/repositories/native_api_session_repository.dart';
import 'pos_bootstrap_remote_data_source.dart';

class NodeBootstrapDataSource implements PosBootstrapRemoteDataSource {
  const NodeBootstrapDataSource(this.sessions);
  final NativeApiSessionRepository sessions;
  @override
  Future<PosBootstrapPage> fetchPage({
    required String organizationId,
    required String branchId,
    required String collection,
    String? snapshotToken,
    String? cursor,
    int pageSize = 250,
  }) async {
    final value = await sessions.authenticated(
      '/v1/pos/bootstrap',
      syncRequest: true,
      body: {
        'branchId': branchId,
        'collection': collection,
        'pageSize': pageSize,
        if (snapshotToken != null) 'snapshotToken': snapshotToken,
        if (cursor != null) 'cursor': cursor,
      },
    );
    if (value['collection'] != collection) {
      throw const FormatException('Bootstrap collection mismatch.');
    }
    return PosBootstrapPage(
      snapshotToken: value['snapshotToken'] as String,
      collection: collection,
      cursor: value['cursor'] as String? ?? '',
      nextCursor: value['nextCursor'] as String?,
      watermark: value['watermark'] as int,
      checksum: value['checksum'] as String,
      rows: (value['rows'] as List)
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList(),
      complete: value['complete'] == true,
    );
  }
}
