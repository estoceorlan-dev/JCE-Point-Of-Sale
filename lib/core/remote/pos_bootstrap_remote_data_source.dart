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
