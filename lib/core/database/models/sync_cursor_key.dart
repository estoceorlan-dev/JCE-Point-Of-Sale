class SyncCursorKey {
  const SyncCursorKey({
    required this.scope,
    this.organizationId,
    this.branchId,
    this.projection,
    this.permissionDigest,
    this.actorUserId,
    this.deviceId,
  });

  final String scope;
  final String? organizationId;
  final String? branchId;
  final String? projection;
  final String? permissionDigest;
  final String? actorUserId;
  final String? deviceId;

  String get value => [
    scope,
    organizationId ?? '_',
    branchId ?? '_',
    projection ?? '_',
    permissionDigest ?? '_',
    actorUserId ?? '_',
    deviceId ?? '_',
  ].join(':');
}
