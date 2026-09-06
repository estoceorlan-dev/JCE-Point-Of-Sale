import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/business_context.dart';
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../remote/firebase_functions_provider.dart';

final administrationSnapshotServiceProvider =
    Provider<AdministrationSnapshotService>((ref) {
      final config = ref.watch(appConfigProvider);
      final functions = ref.watch(firebaseFunctionsProvider);
      return AdministrationSnapshotService(
        database: ref.watch(appDatabaseProvider),
        loadSnapshot: (context) async {
          final response = await functions
              .httpsCallable(config.administrationSnapshotFunctionName)
              .call({'organizationId': context.organizationId});
          return _map(response.data, 'snapshot');
        },
        demoMode: config.enableDemoAuth,
      );
    });

class AdministrationSnapshotService {
  const AdministrationSnapshotService({
    required AppDatabase database,
    required Future<Map<String, Object?>> Function(BusinessContext)
    loadSnapshot,
    required bool demoMode,
  }) : _database = database,
       _loadSnapshot = loadSnapshot,
       _demoMode = demoMode;

  final AppDatabase _database;
  final Future<Map<String, Object?>> Function(BusinessContext) _loadSnapshot;
  final bool _demoMode;

  Future<void> hydrateIfNeeded(
    BusinessContext context, {
    String scopeKey = '',
    bool force = false,
  }) async {
    if (_demoMode) return;
    final metadataKey =
        'admin_snapshot_v2:${context.organizationId}:${context.actorUserId}:$scopeKey';
    if (!force && await _database.metadataDao.readValue(metadataKey) != null) {
      return;
    }
    final snapshot = await _loadSnapshot(context);
    await _applySnapshot(context, snapshot, metadataKey: metadataKey);
  }

  /// Fetch before opening SQLite's transaction. A network or validation failure
  /// must leave the conflict and its local operation recoverable.
  Future<void> acceptRemote(
    BusinessContext context,
    SyncConflict conflict,
  ) async {
    if (conflict.organizationId != context.organizationId ||
        conflict.actorUserId != context.actorUserId) {
      throw StateError(
        'This conflict belongs to another account or organization.',
      );
    }
    final collection = const {
      'branch': 'branches',
      'app_user': 'users',
      'role': 'roles',
      'register': 'registers',
      'tax_category': 'taxCategories',
    }[conflict.entityType];
    if (collection == null || _demoMode) {
      throw StateError('Remote administration recovery is unavailable.');
    }
    final snapshot = await _loadSnapshot(context);
    if (!_list(
      snapshot[collection],
    ).any((value) => _map(value, 'record')['id'] == conflict.entityId)) {
      throw StateError(
        'The remote record is unavailable or outside your administration permissions.',
      );
    }
    await _database.transaction(() async {
      final current = await _database.syncConflictDao.unresolvedForOperation(
        conflict.operationId,
      );
      if (current == null) return;
      final remoteRow = _list(snapshot[collection])
          .map((value) => _map(value, 'record'))
          .firstWhere((row) => row['id'] == conflict.entityId);
      final knownVersion = await _database.syncEntityVersionDao.readVersion(
        organizationId: context.organizationId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
      );
      if (_integer(remoteRow['version']) < knownVersion) {
        throw StateError(
          'The snapshot is older than the latest synchronized version. Retry recovery.',
        );
      }
      final related =
          await (_database.select(_database.syncOutboxEntries)..where(
                (row) =>
                    row.aggregateType.equals(conflict.entityType) &
                    row.aggregateId.equals(conflict.entityId) &
                    row.operationId.equals(conflict.operationId).not() &
                    row.status.isIn(const [
                      'pending',
                      'processing',
                      'retryable_failure',
                      'conflict',
                      'permanent_failure',
                    ]),
              ))
              .get();
      if (related.isNotEmpty) {
        throw StateError(
          'Resolve other pending changes to this record before accepting the remote version.',
        );
      }
      final now = DateTime.now().toUtc();
      await _database.outboxDao.discard(conflict.operationId, now);
      await _applySnapshot(context, snapshot);
      await _database.syncConflictDao.resolve(
        id: conflict.id,
        resolutionStatus: 'accepted_remote',
        resolvedAt: now,
      );
    });
  }

  Future<void> _applySnapshot(
    BusinessContext context,
    Map<String, Object?> snapshot, {
    String? metadataKey,
  }) async {
    if (_integer(snapshot['schemaVersion']) != 1 ||
        _string(snapshot['organizationId']) != context.organizationId) {
      throw const FormatException('Administration snapshot is incompatible.');
    }
    await _database.transaction(() async {
      await _applyBranches(context, _list(snapshot['branches']));
      final users = await _applyUsers(context, _list(snapshot['users']));
      final roles = await _applyRoles(context, _list(snapshot['roles']));
      await _applyRolePermissions(_list(snapshot['rolePermissions']), roles);
      await _applyAssignments(context, _list(snapshot['assignments']), users);
      await _applyRegisters(context, _list(snapshot['registers']));
      await _applyTaxCategories(context, _list(snapshot['taxCategories']));
      final now = DateTime.now().toUtc();
      if (metadataKey != null) {
        await _database.metadataDao.writeValue(
          key: metadataKey,
          value: _string(snapshot['generatedAt']) ?? now.toIso8601String(),
          updatedAt: now,
        );
      }
    });
  }

  Future<void> _applyBranches(
    BusinessContext context,
    List<Object?> values,
  ) async {
    for (final value in values) {
      final row = _map(value, 'branch');
      final id = _requiredString(row, 'id');
      if (!await _canApply(context, 'branch', row)) continue;
      await _rememberVersion(context, 'branch', row);
      await _database
          .into(_database.branches)
          .insertOnConflictUpdate(
            BranchesCompanion.insert(
              id: id,
              organizationId: context.organizationId,
              code: _requiredString(row, 'code'),
              name: _requiredString(row, 'name'),
              timezone: Value(_string(row['timezone']) ?? 'Asia/Manila'),
              addressLineOne: Value(_string(row['addressLineOne'])),
              addressLineTwo: Value(_string(row['addressLineTwo'])),
              city: Value(_string(row['city'])),
              province: Value(_string(row['province'])),
              postalCode: Value(_string(row['postalCode'])),
              phone: Value(_string(row['phone'])),
              email: Value(_string(row['email'])),
              receiptDisplayName: Value(_string(row['receiptDisplayName'])),
              isActive: Value(row['isActive'] == true),
              allowNegativeStock: Value(row['allowNegativeStock'] == true),
              adjustmentApprovalThresholdMilli: Value(
                _nullableInteger(row['adjustmentApprovalThresholdMilli']),
              ),
              allowMultipleOpenShiftsPerUser: Value(
                row['allowMultipleOpenShiftsPerUser'] == true,
              ),
              allowSalesWithoutOpenShift: Value(
                row['allowSalesWithoutOpenShift'] == true,
              ),
              cashDiscrepancyApprovalThresholdMinor: Value(
                _nullableInteger(row['cashDiscrepancyApprovalThresholdMinor']),
              ),
              discountApprovalThresholdBasisPoints: Value(
                _nullableInteger(row['discountApprovalThresholdBasisPoints']),
              ),
              returnApprovalThresholdMinor: Value(
                _nullableInteger(row['returnApprovalThresholdMinor']),
              ),
              voidWindowMinutes: Value(
                _nullableInteger(row['voidWindowMinutes']) ?? 15,
              ),
              transferApprovalThresholdMilli: Value(
                _nullableInteger(row['transferApprovalThresholdMilli']),
              ),
              version: Value(_integer(row['version'])),
              createdAt: _date(row['createdAt']),
              updatedAt: _date(row['updatedAt']),
              deletedAt: Value(_nullableDate(row['deletedAt'])),
            ),
          );
    }
  }

  Future<Set<String>> _applyUsers(
    BusinessContext context,
    List<Object?> values,
  ) async {
    final applied = <String>{};
    for (final value in values) {
      final row = _map(value, 'user');
      final id = _requiredString(row, 'id');
      if (!await _canApply(context, 'app_user', row)) continue;
      applied.add(id);
      // Snapshot assignments replace the current projection, never historical rows.
      await (_database.update(_database.userRoleAssignments)..where(
            (assignment) =>
                assignment.organizationId.equals(context.organizationId) &
                assignment.userId.equals(id) &
                assignment.revokedAt.isNull(),
          ))
          .write(
            UserRoleAssignmentsCompanion(
              revokedAt: Value(_date(row['updatedAt'])),
            ),
          );
      await _rememberVersion(context, 'app_user', row);
      await _database
          .into(_database.appUsers)
          .insertOnConflictUpdate(
            AppUsersCompanion.insert(
              id: id,
              organizationId: context.organizationId,
              firebaseUid: Value(_string(row['firebaseUid'])),
              email: _requiredString(row, 'email'),
              displayName: _requiredString(row, 'displayName'),
              status: _requiredString(row, 'status'),
              invitedAt: Value(_nullableDate(row['invitedAt'])),
              activatedAt: Value(_nullableDate(row['activatedAt'])),
              version: Value(_integer(row['version'])),
              createdAt: _date(row['createdAt']),
              updatedAt: _date(row['updatedAt']),
              deletedAt: Value(_nullableDate(row['deletedAt'])),
            ),
          );
    }
    return applied;
  }

  Future<Set<String>> _applyRoles(
    BusinessContext context,
    List<Object?> values,
  ) async {
    final applied = <String>{};
    for (final value in values) {
      final row = _map(value, 'role');
      final id = _requiredString(row, 'id');
      if (!await _canApply(context, 'role', row)) continue;
      applied.add(id);
      await _rememberVersion(context, 'role', row);
      await _database
          .into(_database.roles)
          .insertOnConflictUpdate(
            RolesCompanion.insert(
              id: id,
              organizationId: context.organizationId,
              code: _requiredString(row, 'code'),
              name: _requiredString(row, 'name'),
              description: Value(_string(row['description'])),
              isActive: Value(row['isActive'] == true),
              version: Value(_integer(row['version'])),
              createdAt: _date(row['createdAt']),
              updatedAt: _date(row['updatedAt']),
              deletedAt: Value(_nullableDate(row['deletedAt'])),
            ),
          );
      await (_database.delete(
        _database.rolePermissions,
      )..where((value) => value.roleId.equals(id))).go();
    }
    return applied;
  }

  Future<void> _applyRolePermissions(
    List<Object?> values,
    Set<String> roles,
  ) async {
    for (final value in values) {
      final row = _map(value, 'role permission');
      final roleId = _requiredString(row, 'roleId');
      if (!roles.contains(roleId)) continue;
      final code = _requiredString(row, 'permissionCode');
      await _database
          .into(_database.permissions)
          .insertOnConflictUpdate(
            PermissionsCompanion.insert(
              code: code,
              name: code,
              createdAt: _date(row['grantedAt']),
            ),
          );
      await _database
          .into(_database.rolePermissions)
          .insert(
            RolePermissionsCompanion.insert(
              roleId: roleId,
              permissionCode: code,
              grantedAt: _date(row['grantedAt']),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _applyAssignments(
    BusinessContext context,
    List<Object?> values,
    Set<String> users,
  ) async {
    for (final value in values) {
      final row = _map(value, 'assignment');
      final id = _requiredString(row, 'id');
      final userId = _requiredString(row, 'userId');
      if (_requiredString(row, 'organizationId') != context.organizationId) {
        throw const FormatException(
          'Assignment is outside the requested organization.',
        );
      }
      if (!users.contains(userId)) continue;
      await _database
          .into(_database.userRoleAssignments)
          .insertOnConflictUpdate(
            UserRoleAssignmentsCompanion.insert(
              id: id,
              organizationId: context.organizationId,
              branchId: Value(_string(row['branchId'])),
              userId: userId,
              roleId: _requiredString(row, 'roleId'),
              assignedAt: _date(row['assignedAt']),
              updatedAt: Value(_nullableDate(row['updatedAt'])),
              revokedAt: Value(_nullableDate(row['revokedAt'])),
              version: Value(_integer(row['version'])),
            ),
          );
    }
  }

  Future<void> _applyRegisters(
    BusinessContext context,
    List<Object?> values,
  ) async {
    for (final value in values) {
      final row = _map(value, 'register');
      final id = _requiredString(row, 'id');
      if (!await _canApply(context, 'register', row)) continue;
      await _rememberVersion(context, 'register', row);
      await _database
          .into(_database.registers)
          .insertOnConflictUpdate(
            RegistersCompanion.insert(
              id: id,
              organizationId: context.organizationId,
              branchId: _requiredString(row, 'branchId'),
              code: _requiredString(row, 'code'),
              name: _requiredString(row, 'name'),
              assignedDeviceId: Value(_string(row['assignedDeviceId'])),
              assignedByUserId: Value(_string(row['assignedByUserId'])),
              assignedAt: Value(_nullableDate(row['assignedAt'])),
              scannerType: Value(
                _string(row['scannerType']) ?? 'keyboard_wedge',
              ),
              scannerInterCharacterTimeoutMs: Value(
                _nullableInteger(row['scannerInterCharacterTimeoutMs']) ?? 80,
              ),
              scannerDuplicateSuppressionMs: Value(
                _nullableInteger(row['scannerDuplicateSuppressionMs']) ?? 350,
              ),
              printerType: Value(_string(row['printerType']) ?? 'screen'),
              printerAddress: Value(_string(row['printerAddress'])),
              printerPort: Value(_nullableInteger(row['printerPort']) ?? 9100),
              printerPaperWidthMm: Value(
                _nullableInteger(row['printerPaperWidthMm']) ?? 80,
              ),
              cashDrawerEnabled: Value(row['cashDrawerEnabled'] == true),
              cashDrawerPin: Value(_nullableInteger(row['cashDrawerPin']) ?? 0),
              isActive: Value(row['isActive'] == true),
              version: Value(_integer(row['version'])),
              createdAt: _date(row['createdAt']),
              updatedAt: _date(row['updatedAt']),
              deletedAt: Value(_nullableDate(row['deletedAt'])),
            ),
          );
    }
  }

  Future<void> _applyTaxCategories(
    BusinessContext context,
    List<Object?> values,
  ) async {
    for (final value in values) {
      final row = _map(value, 'tax category');
      final id = _requiredString(row, 'id');
      if (!await _canApply(context, 'tax_category', row)) continue;
      await _rememberVersion(context, 'tax_category', row);
      await _database
          .into(_database.taxCategories)
          .insertOnConflictUpdate(
            TaxCategoriesCompanion.insert(
              id: id,
              organizationId: context.organizationId,
              code: _requiredString(row, 'code'),
              name: _requiredString(row, 'name'),
              rateBasisPoints: _integer(row['rateBasisPoints']),
              isInclusive: Value(row['isInclusive'] == true),
              isActive: Value(row['isActive'] == true),
              createdAt: _date(row['createdAt']),
              updatedAt: _date(row['updatedAt']),
              deletedAt: Value(_nullableDate(row['deletedAt'])),
            ),
          );
    }
  }

  Future<bool> _hasPending(String aggregateType, String aggregateId) async {
    final row =
        await (_database.select(_database.syncOutboxEntries)
              ..where(
                (value) =>
                    value.aggregateType.equals(aggregateType) &
                    value.aggregateId.equals(aggregateId) &
                    value.status.isIn(const [
                      'pending',
                      'processing',
                      'retryable_failure',
                      'permanent_failure',
                      'conflict',
                    ]),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<bool> _canApply(
    BusinessContext context,
    String type,
    Map<String, Object?> row,
  ) async {
    if (_requiredString(row, 'organizationId') != context.organizationId) {
      throw const FormatException(
        'Snapshot record is outside the requested organization.',
      );
    }
    final id = _requiredString(row, 'id');
    if (await _hasPending(type, id)) return false;
    final knownVersion = await _database.syncEntityVersionDao.readVersion(
      organizationId: context.organizationId,
      entityType: type,
      entityId: id,
    );
    return _integer(row['version']) >= knownVersion;
  }

  Future<void> _rememberVersion(
    BusinessContext context,
    String type,
    Map<String, Object?> row,
  ) async {
    final id = _requiredString(row, 'id');
    final version = _integer(row['version']);
    final now = DateTime.now().toUtc();
    await _database.syncEntityVersionDao.save(
      organizationId: context.organizationId,
      branchId: _string(row['branchId']),
      entityType: type,
      entityId: id,
      remoteVersion: version,
      operationId: 'admin-snapshot:$id',
      updatedAt: now,
    );
    await _database.metadataDao.writeValue(
      key: 'admin_snapshot_version:${context.organizationId}:$type:$id',
      value: version.toString(),
      updatedAt: now,
    );
  }
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Object?> _list(Object? value) => value is List ? value : const [];
String? _string(Object? value) => value is String ? value : null;
String _requiredString(Map<String, Object?> row, String key) =>
    _string(row[key]) ?? (throw FormatException('$key is required.'));
int _integer(Object? value) =>
    _nullableInteger(value) ??
    (throw const FormatException('Integer required.'));
int? _nullableInteger(Object? value) => switch (value) {
  final int item => item,
  final num item => item.toInt(),
  final String item => int.tryParse(item),
  _ => null,
};
DateTime _date(Object? value) =>
    _nullableDate(value) ?? (throw const FormatException('Date required.'));
DateTime? _nullableDate(Object? value) => switch (value) {
  final DateTime item => item.toUtc(),
  final String item => DateTime.tryParse(item)?.toUtc(),
  final Map item when item['_seconds'] is num =>
    DateTime.fromMillisecondsSinceEpoch(
      ((item['_seconds'] as num) * 1000).round(),
      isUtc: true,
    ),
  _ => null,
};
