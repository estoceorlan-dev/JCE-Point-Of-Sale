import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/feature_flag.dart';
import '../../domain/entities/operational_setting.dart';
import '../../domain/entities/reason_code.dart';
import '../../domain/repositories/settings_repository.dart';

class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository({
    required db.AppDatabase database,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final db.AppDatabase _database;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  @override
  Stream<OperationalSettings> watchResolvedSettings({
    required BusinessContext context,
  }) {
    return _database
        .customSelect(
          '''
SELECT setting_key, value_json, version, 'organization' AS setting_scope
FROM organization_settings
WHERE organization_id = ?
UNION ALL
SELECT setting_key, value_json, version, 'branch' AS setting_scope
FROM branch_settings
WHERE organization_id = ? AND branch_id = ?
''',
          variables: [
            Variable<String>(context.organizationId),
            Variable<String>(context.organizationId),
            Variable<String>(context.branchId),
          ],
          readsFrom: {_database.organizationSettings, _database.branchSettings},
        )
        .watch()
        .map((rows) {
          final resolved = Map<OperationalSettingKey, ResolvedSetting>.of(
            OperationalSettings.defaults().values,
          );
          for (final scope in const ['organization', 'branch']) {
            for (final row in rows.where(
              (row) => row.read<String>('setting_scope') == scope,
            )) {
              final key = OperationalSettingKey.fromKey(
                row.read<String>('setting_key'),
              );
              if (key == null) continue;
              final decoded = jsonDecode(row.read<String>('value_json'));
              if (_validationFailure(key, decoded) != null) continue;
              resolved[key] = ResolvedSetting(
                key: key,
                value: decoded,
                origin: scope == 'branch'
                    ? SettingOrigin.branch
                    : SettingOrigin.organization,
                version: row.read<int>('version'),
              );
            }
          }
          return OperationalSettings(resolved);
        });
  }

  @override
  Future<Result<void, Failure>> saveSetting({
    required BusinessContext context,
    required SettingScope scope,
    required OperationalSettingKey key,
    required Object? value,
    String? operationId,
  }) async {
    final validation = _validationFailure(key, value);
    if (validation != null) return Result.failure(validation);
    try {
      final op = operationId ?? _idGenerator.newId();
      final commandType = scope == SettingScope.branch
          ? 'setting.branch.upsert'
          : 'setting.organization.upsert';
      final id = _settingId(context, scope, key);
      if (await _isDuplicateOperation(op, commandType, id)) {
        return const Result.success(null);
      }
      final existing = await _readSetting(context, scope, key);
      final now = _clock.nowUtc();
      final version = existing == null ? 0 : existing.version + 1;
      final encoded = jsonEncode(value);
      return _localMutationTransaction.execute(
        businessWrite: (database) async {
          if (scope == SettingScope.organization) {
            await database
                .into(database.organizationSettings)
                .insertOnConflictUpdate(
                  db.OrganizationSettingsCompanion.insert(
                    id: id,
                    organizationId: context.organizationId,
                    settingKey: key.key,
                    valueJson: encoded,
                    version: Value(version),
                    updatedByUserId: context.actorUserId,
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  ),
                );
          } else {
            await database
                .into(database.branchSettings)
                .insertOnConflictUpdate(
                  db.BranchSettingsCompanion.insert(
                    id: id,
                    organizationId: context.organizationId,
                    branchId: context.branchId,
                    settingKey: key.key,
                    valueJson: encoded,
                    version: Value(version),
                    updatedByUserId: context.actorUserId,
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  ),
                );
          }
          await _updateLegacyBranchProjection(
            database,
            context,
            scope,
            key,
            value,
            now,
          );
        },
        auditEntry: _audit(
          context: context,
          operationId: op,
          entityId: id,
          branchId: scope == SettingScope.branch ? context.branchId : null,
          now: now,
          metadata: {
            'scope': scope.name,
            'key': key.key,
            'before': existing?.value,
            'after': value,
          },
        ),
        outboxCommand: _outbox(
          context: context,
          operationId: op,
          commandType: commandType,
          aggregateType: scope == SettingScope.branch
              ? 'branch_setting'
              : 'organization_setting',
          aggregateId: id,
          payload: {
            'id': id,
            'key': key.key,
            'value': value,
            'expectedVersion': existing?.version,
          },
          now: now,
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }

  @override
  Future<Result<void, Failure>> clearBranchOverride({
    required BusinessContext context,
    required OperationalSettingKey key,
    String? operationId,
  }) async {
    try {
      final existing = await _readSetting(context, SettingScope.branch, key);
      if (existing == null) return const Result.success(null);
      final op = operationId ?? _idGenerator.newId();
      if (await _isDuplicateOperation(
        op,
        'setting.branch.delete',
        existing.id,
      )) {
        return const Result.success(null);
      }
      final now = _clock.nowUtc();
      final inherited = await _organizationValue(context, key);
      return _localMutationTransaction.execute(
        businessWrite: (database) async {
          await (database.delete(database.branchSettings)..where(
                (row) =>
                    row.id.equals(existing.id) &
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId),
              ))
              .go();
          await _updateLegacyBranchProjection(
            database,
            context,
            SettingScope.branch,
            key,
            inherited,
            now,
          );
        },
        auditEntry: _audit(
          context: context,
          operationId: op,
          entityId: existing.id,
          branchId: context.branchId,
          now: now,
          metadata: {
            'scope': SettingScope.branch.name,
            'key': key.key,
            'before': existing.value,
            'after': inherited,
            'overrideRemoved': true,
          },
        ),
        outboxCommand: _outbox(
          context: context,
          operationId: op,
          commandType: 'setting.branch.delete',
          aggregateType: 'branch_setting',
          aggregateId: existing.id,
          payload: {
            'id': existing.id,
            'key': key.key,
            'expectedVersion': existing.version,
          },
          now: now,
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }

  @override
  Stream<List<ReasonCode>> watchReasonCodes({
    required BusinessContext context,
    ReasonCodeCategory? category,
    bool includeInactive = false,
  }) {
    final query = _database.select(_database.reasonCodes)
      ..where(
        (row) =>
            row.organizationId.equals(context.organizationId) &
            (row.branchId.isNull() | row.branchId.equals(context.branchId)) &
            row.deletedAt.isNull(),
      );
    if (category != null) {
      query.where((row) => row.category.equals(category.databaseValue));
    }
    if (!includeInactive) query.where((row) => row.isActive.equals(true));
    query.orderBy([
      (row) => OrderingTerm.asc(row.sortOrder),
      (row) => OrderingTerm.asc(row.label),
    ]);
    return query.watch().map((rows) {
      final effective = <String, db.ReasonCode>{};
      for (final row in rows.where((row) => row.branchId == null)) {
        effective['${row.category}|${row.code}'] = row;
      }
      for (final row in rows.where((row) => row.branchId != null)) {
        effective['${row.category}|${row.code}'] = row;
      }
      final values = effective.values.map(_reasonCode).toList(growable: false)
        ..sort((left, right) {
          final order = left.sortOrder.compareTo(right.sortOrder);
          return order != 0 ? order : left.label.compareTo(right.label);
        });
      return values;
    });
  }

  @override
  Future<Result<String, Failure>> saveReasonCode({
    required BusinessContext context,
    required ReasonCodeDraft draft,
  }) async {
    final code = draft.code.trim().toUpperCase().replaceAll(
      RegExp('[^A-Z0-9_]+'),
      '_',
    );
    final label = draft.label.trim();
    if (code.length < 2 ||
        code.length > 40 ||
        label.length < 2 ||
        label.length > 80) {
      return const Result.failure(
        ValidationFailure(
          'Reason code and label must contain 2 to 80 characters.',
        ),
      );
    }
    try {
      final id = draft.id ?? _idGenerator.newId();
      final op = draft.operationId ?? _idGenerator.newId();
      final existing =
          await (_database.select(_database.reasonCodes)..where(
                (row) =>
                    row.id.equals(id) &
                    row.organizationId.equals(context.organizationId),
              ))
              .getSingleOrNull();
      if (existing != null &&
          draft.expectedVersion != null &&
          existing.version != draft.expectedVersion) {
        return const Result.failure(
          ConflictFailure('The reason code changed. Refresh and try again.'),
        );
      }
      if (await _isDuplicateOperation(op, 'reason_code.upsert', id)) {
        return Result.success(id);
      }
      final requestedBranchId = draft.scope == SettingScope.branch
          ? context.branchId
          : null;
      if (existing != null &&
          (existing.branchId != requestedBranchId ||
              existing.category != draft.category.databaseValue ||
              existing.code != code)) {
        return const Result.failure(
          ValidationFailure(
            'A reason code scope, category, and code cannot be changed.',
          ),
        );
      }
      final duplicate =
          await (_database.select(_database.reasonCodes)..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchScope.equals(
                      draft.scope == SettingScope.branch
                          ? context.branchId
                          : '*',
                    ) &
                    row.category.equals(draft.category.databaseValue) &
                    row.code.equals(code) &
                    row.id.equals(id).not(),
              ))
              .getSingleOrNull();
      if (duplicate != null) {
        return const Result.failure(
          ConflictFailure('That reason code already exists in this scope.'),
        );
      }
      final now = _clock.nowUtc();
      final version = existing == null ? 0 : existing.version + 1;
      final result = await _localMutationTransaction.execute(
        businessWrite: (database) async {
          await database
              .into(database.reasonCodes)
              .insertOnConflictUpdate(
                db.ReasonCodesCompanion.insert(
                  id: id,
                  organizationId: context.organizationId,
                  branchId: Value(
                    draft.scope == SettingScope.branch
                        ? context.branchId
                        : null,
                  ),
                  branchScope: draft.scope == SettingScope.branch
                      ? context.branchId
                      : '*',
                  category: draft.category.databaseValue,
                  code: code,
                  label: label,
                  requiresNote: Value(draft.requiresNote),
                  isActive: Value(draft.isActive),
                  sortOrder: Value(draft.sortOrder),
                  version: Value(version),
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                ),
              );
        },
        auditEntry: _audit(
          context: context,
          operationId: op,
          entityId: id,
          branchId: draft.scope == SettingScope.branch
              ? context.branchId
              : null,
          now: now,
          entityName: 'reason_code',
          metadata: {
            'before': existing == null ? null : _reasonPayload(existing),
            'after': {
              'category': draft.category.databaseValue,
              'code': code,
              'label': label,
              'requiresNote': draft.requiresNote,
              'isActive': draft.isActive,
              'sortOrder': draft.sortOrder,
              'scope': draft.scope.name,
            },
          },
        ),
        outboxCommand: _outbox(
          context: context,
          operationId: op,
          commandType: 'reason_code.upsert',
          aggregateType: 'reason_code',
          aggregateId: id,
          payload: {
            'id': id,
            'branchId': draft.scope == SettingScope.branch
                ? context.branchId
                : null,
            'category': draft.category.databaseValue,
            'code': code,
            'label': label,
            'requiresNote': draft.requiresNote,
            'isActive': draft.isActive,
            'sortOrder': draft.sortOrder,
            'expectedVersion': existing?.version,
          },
          now: now,
        ),
      );
      return result.fold(
        onSuccess: (_) => Result.success(id),
        onFailure: Result.failure,
      );
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }

  @override
  Stream<List<FeatureFlag>> watchFeatureFlags({
    required BusinessContext context,
  }) {
    final query = _database.select(_database.featureFlags)
      ..where(
        (row) =>
            row.organizationId.equals(context.organizationId) &
            (row.branchId.isNull() | row.branchId.equals(context.branchId)),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.flagKey)]);
    return query.watch().map((rows) {
      final effective = <String, db.FeatureFlag>{};
      for (final row in rows.where((row) => row.branchId == null)) {
        effective[row.flagKey] = row;
      }
      for (final row in rows.where((row) => row.branchId != null)) {
        effective[row.flagKey] = row;
      }
      return effective.values.map(_featureFlag).toList(growable: false);
    });
  }

  @override
  Future<Result<void, Failure>> saveFeatureFlag({
    required BusinessContext context,
    required String key,
    required bool isEnabled,
    required SettingScope scope,
    Map<String, Object?> configuration = const {},
    String? operationId,
  }) async {
    final normalizedKey = key.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_.-]{1,63}$').hasMatch(normalizedKey)) {
      return const Result.failure(
        ValidationFailure('Feature flag key is invalid.'),
      );
    }
    try {
      final id = _scopedId(context, scope, 'flag:$normalizedKey');
      final existing = await (_database.select(
        _database.featureFlags,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      final op = operationId ?? _idGenerator.newId();
      if (await _isDuplicateOperation(op, 'feature_flag.upsert', id)) {
        return const Result.success(null);
      }
      final now = _clock.nowUtc();
      final version = existing == null ? 0 : existing.version + 1;
      return _localMutationTransaction.execute(
        businessWrite: (database) => database
            .into(database.featureFlags)
            .insertOnConflictUpdate(
              db.FeatureFlagsCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                branchId: Value(
                  scope == SettingScope.branch ? context.branchId : null,
                ),
                branchScope: scope == SettingScope.branch
                    ? context.branchId
                    : '*',
                flagKey: normalizedKey,
                isEnabled: Value(isEnabled),
                configurationJson: Value(jsonEncode(configuration)),
                version: Value(version),
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
              ),
            ),
        auditEntry: _audit(
          context: context,
          operationId: op,
          entityId: id,
          branchId: scope == SettingScope.branch ? context.branchId : null,
          now: now,
          entityName: 'feature_flag',
          metadata: {
            'key': normalizedKey,
            'before': existing?.isEnabled,
            'after': isEnabled,
            'scope': scope.name,
          },
        ),
        outboxCommand: _outbox(
          context: context,
          operationId: op,
          commandType: 'feature_flag.upsert',
          aggregateType: 'feature_flag',
          aggregateId: id,
          payload: {
            'id': id,
            'branchId': scope == SettingScope.branch ? context.branchId : null,
            'key': normalizedKey,
            'isEnabled': isEnabled,
            'configuration': configuration,
            'expectedVersion': existing?.version,
          },
          now: now,
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }

  Future<_StoredSetting?> _readSetting(
    BusinessContext context,
    SettingScope scope,
    OperationalSettingKey key,
  ) async {
    if (scope == SettingScope.organization) {
      final row =
          await (_database.select(_database.organizationSettings)..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.settingKey.equals(key.key),
              ))
              .getSingleOrNull();
      return row == null
          ? null
          : _StoredSetting(
              id: row.id,
              value: jsonDecode(row.valueJson),
              version: row.version,
              createdAt: row.createdAt,
            );
    }
    final row =
        await (_database.select(_database.branchSettings)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.settingKey.equals(key.key),
            ))
            .getSingleOrNull();
    return row == null
        ? null
        : _StoredSetting(
            id: row.id,
            value: jsonDecode(row.valueJson),
            version: row.version,
            createdAt: row.createdAt,
          );
  }

  Future<Object?> _organizationValue(
    BusinessContext context,
    OperationalSettingKey key,
  ) async {
    final setting = await _readSetting(context, SettingScope.organization, key);
    return setting?.value ?? key.defaultValue;
  }

  Future<bool> _isDuplicateOperation(
    String operationId,
    String type,
    String aggregateId,
  ) async {
    final existing = await (_database.select(
      _database.syncOutboxEntries,
    )..where((row) => row.operationId.equals(operationId))).getSingleOrNull();
    if (existing == null) return false;
    if (existing.commandType != type || existing.aggregateId != aggregateId) {
      throw const ConflictFailure(
        'The operation ID belongs to another action.',
      );
    }
    return true;
  }

  Future<void> _updateLegacyBranchProjection(
    db.AppDatabase database,
    BusinessContext context,
    SettingScope scope,
    OperationalSettingKey key,
    Object? value,
    DateTime now,
  ) async {
    final projection = _legacyProjection(key, value, now);
    if (projection == null) return;
    if (scope == SettingScope.branch) {
      await (database.update(database.branches)..where(
            (row) =>
                row.organizationId.equals(context.organizationId) &
                row.id.equals(context.branchId),
          ))
          .write(projection);
      return;
    }
    final overrides =
        await (database.select(database.branchSettings)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.settingKey.equals(key.key),
            ))
            .get();
    final overriddenIds = overrides.map((row) => row.branchId).toList();
    final update = database.update(database.branches)
      ..where((row) => row.organizationId.equals(context.organizationId));
    if (overriddenIds.isNotEmpty) {
      update.where((row) => row.id.isNotIn(overriddenIds));
    }
    await update.write(projection);
  }

  db.BranchesCompanion? _legacyProjection(
    OperationalSettingKey key,
    Object? value,
    DateTime now,
  ) => switch (key) {
    OperationalSettingKey.inventoryAllowNegativeStock => db.BranchesCompanion(
      allowNegativeStock: Value(value as bool),
      updatedAt: Value(now),
    ),
    OperationalSettingKey.inventoryAdjustmentApprovalThresholdMilli =>
      db.BranchesCompanion(
        adjustmentApprovalThresholdMilli: Value(value as int?),
        updatedAt: Value(now),
      ),
    OperationalSettingKey.salesDiscountApprovalThresholdBasisPoints =>
      db.BranchesCompanion(
        discountApprovalThresholdBasisPoints: Value(value as int?),
        updatedAt: Value(now),
      ),
    OperationalSettingKey.shiftsAllowMultipleOpen => db.BranchesCompanion(
      allowMultipleOpenShiftsPerUser: Value(value as bool),
      updatedAt: Value(now),
    ),
    OperationalSettingKey.shiftsAllowSalesWithoutOpen => db.BranchesCompanion(
      allowSalesWithoutOpenShift: Value(value as bool),
      updatedAt: Value(now),
    ),
    OperationalSettingKey.shiftsCashDiscrepancyApprovalThresholdMinor =>
      db.BranchesCompanion(
        cashDiscrepancyApprovalThresholdMinor: Value(value as int?),
        updatedAt: Value(now),
      ),
    OperationalSettingKey.returnsApprovalThresholdMinor => db.BranchesCompanion(
      returnApprovalThresholdMinor: Value(value as int?),
      updatedAt: Value(now),
    ),
    OperationalSettingKey.returnsVoidWindowMinutes => db.BranchesCompanion(
      voidWindowMinutes: Value(value as int),
      updatedAt: Value(now),
    ),
    OperationalSettingKey.transfersApprovalThresholdMilli =>
      db.BranchesCompanion(
        transferApprovalThresholdMilli: Value(value as int?),
        updatedAt: Value(now),
      ),
    _ => null,
  };

  AuditLogEntry _audit({
    required BusinessContext context,
    required String operationId,
    required String entityId,
    required String? branchId,
    required DateTime now,
    required Map<String, Object?> metadata,
    String entityName = 'setting',
  }) => AuditLogEntry(
    id: _idGenerator.newId(),
    operationId: operationId,
    organizationId: context.organizationId,
    actorUserId: context.actorUserId,
    branchId: branchId,
    actionType: AuditActionType.settingChange,
    entityName: entityName,
    entityId: entityId,
    metadata: metadata,
    createdAt: now,
  );

  OutboxCommand _outbox({
    required BusinessContext context,
    required String operationId,
    required String commandType,
    required String aggregateType,
    required String aggregateId,
    required Map<String, Object?> payload,
    required DateTime now,
  }) => OutboxCommand(
    operationId: operationId,
    organizationId: context.organizationId,
    branchId: context.branchId,
    actorUserId: context.actorUserId,
    commandType: commandType,
    aggregateType: aggregateType,
    aggregateId: aggregateId,
    payload: payload,
    createdAt: now,
  );

  String _settingId(
    BusinessContext context,
    SettingScope scope,
    OperationalSettingKey key,
  ) => _scopedId(context, scope, 'setting:${key.key}');

  String _scopedId(BusinessContext context, SettingScope scope, String value) =>
      '${context.organizationId}:'
      '${scope == SettingScope.branch ? context.branchId : '*'}:$value';

  ReasonCode _reasonCode(db.ReasonCode row) => ReasonCode(
    id: row.id,
    organizationId: row.organizationId,
    branchId: row.branchId,
    category: ReasonCodeCategory.fromDatabase(row.category),
    code: row.code,
    label: row.label,
    requiresNote: row.requiresNote,
    isActive: row.isActive,
    sortOrder: row.sortOrder,
    scope: row.branchId == null
        ? SettingScope.organization
        : SettingScope.branch,
    version: row.version,
  );

  FeatureFlag _featureFlag(db.FeatureFlag row) => FeatureFlag(
    id: row.id,
    key: row.flagKey,
    isEnabled: row.isEnabled,
    configuration: (jsonDecode(row.configurationJson) as Map<String, dynamic>)
        .cast<String, Object?>(),
    scope: row.branchId == null
        ? SettingScope.organization
        : SettingScope.branch,
    version: row.version,
    branchId: row.branchId,
  );
}

class _StoredSetting {
  const _StoredSetting({
    required this.id,
    required this.value,
    required this.version,
    required this.createdAt,
  });

  final String id;
  final Object? value;
  final int version;
  final DateTime createdAt;
}

ValidationFailure? _validationFailure(
  OperationalSettingKey key,
  Object? value,
) {
  if (value == null) {
    return key.allowsNull
        ? null
        : ValidationFailure('${key.label} cannot be empty.');
  }
  switch (key) {
    case OperationalSettingKey.taxBehavior:
      if (value is! String ||
          !const {'per_product', 'inclusive', 'exclusive'}.contains(value)) {
        return const ValidationFailure('Tax behavior is invalid.');
      }
    case OperationalSettingKey.receiptHeader:
      if (value is! String || value.trim().isEmpty || value.length > 80) {
        return const ValidationFailure(
          'Receipt header must be 1 to 80 characters.',
        );
      }
    case OperationalSettingKey.receiptFooter:
      if (value is! String || value.length > 160) {
        return const ValidationFailure(
          'Receipt footer cannot exceed 160 characters.',
        );
      }
    case OperationalSettingKey.receiptPaperWidth:
      if (value is! int || !const {32, 42, 48}.contains(value)) {
        return const ValidationFailure('Receipt width must be 32, 42, or 48.');
      }
    case OperationalSettingKey.salesDiscountLimitBasisPoints ||
        OperationalSettingKey.salesDiscountApprovalThresholdBasisPoints:
      if (value is! int || value < 0 || value > 10000) {
        return const ValidationFailure(
          'Discount values must be between 0 and 10000 basis points.',
        );
      }
    case OperationalSettingKey.returnsVoidWindowMinutes:
      if (value is! int || value < 0 || value > 10080) {
        return const ValidationFailure(
          'Void window must be between 0 and 10080 minutes.',
        );
      }
    case OperationalSettingKey.inventoryAdjustmentApprovalThresholdMilli ||
        OperationalSettingKey.shiftsCashDiscrepancyApprovalThresholdMinor ||
        OperationalSettingKey.returnsApprovalThresholdMinor ||
        OperationalSettingKey.transfersApprovalThresholdMilli:
      if (value is! int || value < 0) {
        return ValidationFailure('${key.label} cannot be negative.');
      }
    case OperationalSettingKey.salesRequireNonCashReference ||
        OperationalSettingKey.inventoryAllowNegativeStock ||
        OperationalSettingKey.receiptShowTaxBreakdown ||
        OperationalSettingKey.shiftsAllowMultipleOpen ||
        OperationalSettingKey.shiftsAllowSalesWithoutOpen:
      if (value is! bool) {
        return ValidationFailure('${key.label} must be enabled or disabled.');
      }
  }
  return null;
}

Map<String, Object?> _reasonPayload(db.ReasonCode row) => {
  'category': row.category,
  'code': row.code,
  'label': row.label,
  'requiresNote': row.requiresNote,
  'isActive': row.isActive,
  'sortOrder': row.sortOrder,
  'scope': row.branchId == null ? 'organization' : 'branch',
};
