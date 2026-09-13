import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/database/models/outbox_state.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/register_claim.dart';
import '../../domain/entities/register_claim_action_grant.dart';
import '../../domain/repositories/register_claim_repository.dart';

class DriftRegisterClaimRepository implements RegisterClaimRepository {
  const DriftRegisterClaimRepository({
    required AppDatabase database,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final AppDatabase _database;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  @override
  Stream<RegisterClaim?> watchInstallationClaim({
    required BusinessContext context,
    required String deviceId,
  }) {
    final query = _database.select(_database.registerClaims)
      ..where(
        (row) =>
            row.organizationId.equals(context.organizationId) &
            row.branchId.equals(context.branchId) &
            row.deviceId.equals(deviceId) &
            row.status.isIn([
              'provisional',
              'accepted',
              'rejected',
              'resolved',
            ]),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(1);
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  @override
  Future<RegisterClaim?> getInstallationClaim({
    required BusinessContext context,
    required String deviceId,
  }) async {
    return watchInstallationClaim(context: context, deviceId: deviceId).first;
  }

  @override
  Future<Result<RegisterClaim, Failure>> claim({
    required BusinessContext context,
    required String registerId,
    required String deviceId,
    required int expectedVersion,
  }) async {
    final activeClaim =
        await (_database.select(_database.registerClaims)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.deviceId.equals(deviceId) &
                    row.status.isIn(['provisional', 'accepted', 'resolved']),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (activeClaim != null) {
      final effectiveRegisterId =
          activeClaim.resolvedRegisterId ?? activeClaim.requestedRegisterId;
      if (effectiveRegisterId == registerId) {
        return Result.success(_toDomain(activeClaim));
      }
      return const Result.failure(
        ConflictFailure(
          'This installation is already pinned to another register.',
        ),
      );
    }
    final dependencies = <String>{
      ...await _pendingDependencies('device', deviceId),
      ...await _pendingDependencies('register', registerId),
    }.toList(growable: false);
    final claimId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final register =
            await (database.select(database.registers)..where(
                  (row) =>
                      row.id.equals(registerId) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.isActive.equals(true) &
                      row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (register == null) {
          throw const AuthorizationFailure(
            'The register is not active in this branch.',
          );
        }
        if (register.version != expectedVersion) {
          throw const ConflictFailure(
            'The register changed. Refresh before claiming it.',
          );
        }
        if (register.assignedDeviceId != null &&
            register.assignedDeviceId != deviceId) {
          throw const ConflictFailure(
            'This register is already claimed by another installation.',
          );
        }
        final other =
            await (database.select(database.registers)
                  ..where(
                    (row) =>
                        row.organizationId.equals(context.organizationId) &
                        row.assignedDeviceId.equals(deviceId) &
                        row.id.equals(registerId).not() &
                        row.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (other != null) {
          throw const ConflictFailure(
            'This installation is already pinned to another register.',
          );
        }
        await database
            .into(database.registerClaims)
            .insert(
              RegisterClaimsCompanion.insert(
                id: claimId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                requestedRegisterId: registerId,
                deviceId: deviceId,
                claimedByUserId: context.actorUserId,
                status: RegisterClaimStatus.provisional.name,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await (database.update(
          database.registers,
        )..where((row) => row.id.equals(registerId))).write(
          RegistersCompanion(
            assignedDeviceId: Value(deviceId),
            assignedByUserId: Value(context.actorUserId),
            assignedAt: Value(now),
            version: Value(register.version + 1),
            updatedAt: Value(now),
          ),
        );
        await database.metadataDao.writeValue(
          key: _pinKey(context.organizationId, deviceId),
          value: context.branchId,
          updatedAt: now,
        );
        return RegisterClaim(
          id: claimId,
          organizationId: context.organizationId,
          branchId: context.branchId,
          requestedRegisterId: registerId,
          deviceId: deviceId,
          claimedByUserId: context.actorUserId,
          status: RegisterClaimStatus.provisional,
          version: 0,
          createdAt: now,
        );
      },
      auditEntry: _audit(context, claimId, 'register_claim', claimId, {
        'registerId': registerId,
        'deviceId': deviceId,
        'provisional': true,
      }, now),
      outboxCommand: OutboxCommand(
        operationId: claimId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        commandType: 'register.claim',
        aggregateType: 'register_claim',
        aggregateId: claimId,
        causalGroupId: claimId,
        dependencyOperationIds: dependencies,
        payload: {
          'claimId': claimId,
          'registerId': registerId,
          'deviceId': deviceId,
          'expectedVersion': expectedVersion,
        },
        createdAt: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> resolve({
    required BusinessContext context,
    required String claimId,
    required String targetRegisterId,
    RegisterClaimActionGrant? managerGrant,
  }) async {
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final claim =
            await (database.select(database.registerClaims)..where(
                  (row) =>
                      row.id.equals(claimId) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.status.equals('rejected'),
                ))
                .getSingleOrNull();
        if (claim == null) {
          throw const ConflictFailure(
            'The rejected claim is no longer available.',
          );
        }
        final target =
            await (database.select(database.registers)..where(
                  (row) =>
                      row.id.equals(targetRegisterId) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.isActive.equals(true) &
                      row.assignedDeviceId.isNull() &
                      row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (target == null) {
          throw const ConflictFailure(
            'Select an active unclaimed register in the same branch.',
          );
        }
      },
      auditEntry: _audit(context, operationId, 'register_claim', claimId, {
        'targetRegisterId': targetRegisterId,
      }, now),
      outboxCommand: OutboxCommand(
        operationId: operationId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        commandType: 'register.claim.resolve',
        aggregateType: 'register_claim',
        aggregateId: claimId,
        payload: {
          'claimId': claimId,
          'targetRegisterId': targetRegisterId,
          'managerGrantId': managerGrant?.id,
          'managerGrantNonce': managerGrant?.nonce,
        },
        createdAt: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> release({
    required BusinessContext context,
    required String registerId,
    required String deviceId,
  }) async {
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    final activeClaim =
        await (_database.select(_database.registerClaims)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
                    row.deviceId.equals(deviceId) &
                    row.status.isIn(['provisional', 'accepted', 'resolved']),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (activeClaim != null) {
      final pending =
          await (_database.select(_database.syncOutboxEntries)
                ..where(
                  (row) =>
                      row.causalGroupId.equals(activeClaim.id) &
                      row.status.isNotIn([
                        OutboxState.succeeded.databaseValue,
                        OutboxState.discarded.databaseValue,
                      ]),
                )
                ..limit(1))
              .getSingleOrNull();
      if (pending != null) {
        return const Result.failure(
          ConflictFailure(
            'Synchronize every shift, sale, and cash operation before releasing this register.',
          ),
        );
      }
    }
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final openShift =
            await (database.select(database.shifts)
                  ..where(
                    (row) =>
                        row.organizationId.equals(context.organizationId) &
                        row.branchId.equals(context.branchId) &
                        row.registerId.equals(registerId) &
                        row.status.equals('open'),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (openShift != null) {
          throw const ConflictFailure(
            'Close the shift before releasing this register.',
          );
        }
        await (database.update(database.registers)..where(
              (row) =>
                  row.id.equals(registerId) &
                  row.assignedDeviceId.equals(deviceId),
            ))
            .write(
              RegistersCompanion(
                assignedDeviceId: const Value(null),
                assignedByUserId: const Value(null),
                assignedAt: const Value(null),
                updatedAt: Value(now),
              ),
            );
      },
      auditEntry: _audit(context, operationId, 'register', registerId, {
        'releasedDeviceId': deviceId,
      }, now),
      outboxCommand: OutboxCommand(
        operationId: operationId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        commandType: 'register.release',
        aggregateType: 'register',
        aggregateId: registerId,
        causalGroupId: activeClaim?.id,
        payload: {'registerId': registerId, 'deviceId': deviceId},
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> discardProvisionalClaim({
    required String claimId,
    required String deviceId,
  }) async {
    await _database.transaction(() async {
      final claim =
          await (_database.select(_database.registerClaims)..where(
                (row) =>
                    row.id.equals(claimId) &
                    row.deviceId.equals(deviceId) &
                    row.status.equals('provisional'),
              ))
              .getSingleOrNull();
      if (claim == null) return;
      await (_database.update(_database.registers)..where(
            (row) =>
                row.id.equals(claim.requestedRegisterId) &
                row.assignedDeviceId.equals(deviceId),
          ))
          .write(
            RegistersCompanion(
              assignedDeviceId: const Value(null),
              assignedByUserId: const Value(null),
              assignedAt: const Value(null),
              updatedAt: Value(_clock.nowUtc()),
            ),
          );
      await _database.outboxDao.discard(claimId, _clock.nowUtc());
      await (_database.delete(
        _database.registerClaims,
      )..where((row) => row.id.equals(claimId))).go();
    });
  }

  @override
  Future<void> applyResolutionDirective({
    required String organizationId,
    required String branchId,
    required String claimId,
    required String targetRegisterId,
    required String deviceId,
    required String? managerUserId,
    required DateTime resolvedAt,
  }) async {
    await _database.transaction(() async {
      final claim = await (_database.select(
        _database.registerClaims,
      )..where((row) => row.id.equals(claimId))).getSingleOrNull();
      if (claim == null) return;
      final oldRegisterId = claim.requestedRegisterId;
      await (_database.update(
        _database.shifts,
      )..where((row) => row.registerClaimId.equals(claimId))).write(
        ShiftsCompanion(
          registerId: Value(targetRegisterId),
          updatedAt: Value(resolvedAt),
        ),
      );
      await (_database.update(_database.cashMovements)
            ..where((row) => row.registerClaimId.equals(claimId)))
          .write(CashMovementsCompanion(registerId: Value(targetRegisterId)));
      await (_database.update(
        _database.sales,
      )..where((row) => row.registerClaimId.equals(claimId))).write(
        SalesCompanion(
          registerId: Value(targetRegisterId),
          updatedAt: Value(resolvedAt),
        ),
      );
      await (_database.update(
        _database.receiptPrintJobs,
      )..where((row) => row.registerClaimId.equals(claimId))).write(
        ReceiptPrintJobsCompanion(
          registerId: Value(targetRegisterId),
          updatedAt: Value(resolvedAt),
        ),
      );
      final pendingCommands =
          await (_database.select(_database.syncOutboxEntries)..where(
                (row) =>
                    row.causalGroupId.equals(claimId) &
                    row.status.isNotIn([
                      OutboxState.succeeded.databaseValue,
                      OutboxState.discarded.databaseValue,
                    ]),
              ))
              .get();
      for (final command in pendingCommands) {
        final decoded = jsonDecode(command.payloadJson);
        if (decoded is! Map) continue;
        final payload = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        if (payload['registerId'] == oldRegisterId) {
          payload['registerId'] = targetRegisterId;
          await (_database.update(
            _database.syncOutboxEntries,
          )..where((row) => row.operationId.equals(command.operationId))).write(
            SyncOutboxEntriesCompanion(
              payloadJson: Value(jsonEncode(payload)),
              status: Value(OutboxState.pending.databaseValue),
              nextAttemptAt: const Value(null),
              lastError: const Value(null),
              updatedAt: Value(resolvedAt),
            ),
          );
        }
      }
      await _database.outboxDao.markSucceeded(
        operationId: claimId,
        now: resolvedAt,
      );
      await (_database.update(
        _database.registers,
      )..where((row) => row.id.equals(oldRegisterId))).write(
        RegistersCompanion(
          assignedDeviceId: const Value(null),
          assignedByUserId: const Value(null),
          assignedAt: const Value(null),
          updatedAt: Value(resolvedAt),
        ),
      );
      await (_database.update(
        _database.registers,
      )..where((row) => row.id.equals(targetRegisterId))).write(
        RegistersCompanion(
          assignedDeviceId: Value(deviceId),
          assignedByUserId: Value(managerUserId),
          assignedAt: Value(resolvedAt),
          updatedAt: Value(resolvedAt),
        ),
      );
      await (_database.update(
        _database.registerClaims,
      )..where((row) => row.id.equals(claimId))).write(
        RegisterClaimsCompanion(
          resolvedRegisterId: Value(targetRegisterId),
          status: const Value('resolved'),
          resolvedByUserId: Value(managerUserId),
          resolvedAt: Value(resolvedAt),
          updatedAt: Value(resolvedAt),
        ),
      );
    });
  }

  AuditLogEntry _audit(
    BusinessContext context,
    String operationId,
    String entityName,
    String entityId,
    Map<String, Object?> metadata,
    DateTime now,
  ) {
    return AuditLogEntry(
      id: _idGenerator.newId(),
      operationId: operationId,
      organizationId: context.organizationId,
      actorUserId: context.actorUserId,
      branchId: context.branchId,
      actionType: AuditActionType.update,
      entityName: entityName,
      entityId: entityId,
      metadata: metadata,
      createdAt: now,
    );
  }

  RegisterClaim _toDomain(RegisterClaimRecord row) => RegisterClaim(
    id: row.id,
    organizationId: row.organizationId,
    branchId: row.branchId,
    requestedRegisterId: row.requestedRegisterId,
    resolvedRegisterId: row.resolvedRegisterId,
    deviceId: row.deviceId,
    claimedByUserId: row.claimedByUserId,
    status: RegisterClaimStatus.fromDatabase(row.status),
    rejectionCode: row.rejectionCode,
    rejectionMessage: row.rejectionMessage,
    version: row.version,
    createdAt: row.createdAt,
  );

  Future<List<String>> _pendingDependencies(
    String aggregateType,
    String aggregateId,
  ) async {
    final operations =
        await (_database.select(_database.syncOutboxEntries)
              ..where(
                (row) =>
                    row.aggregateType.equals(aggregateType) &
                    row.aggregateId.equals(aggregateId) &
                    row.status.isNotIn([
                      OutboxState.succeeded.databaseValue,
                      OutboxState.discarded.databaseValue,
                    ]),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();
    return operations.map((operation) => operation.operationId).toList();
  }
}

String _pinKey(String organizationId, String deviceId) =>
    'terminal.pinned_branch:$organizationId:$deviceId';
