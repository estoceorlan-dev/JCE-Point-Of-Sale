import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/receipt_print_job.dart' as domain;
import '../../domain/entities/register_hardware_profile.dart';
import '../../domain/repositories/pos_hardware_repository.dart';

class DriftPosHardwareRepository implements PosHardwareRepository {
  const DriftPosHardwareRepository({
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
  Stream<RegisterHardwareProfile?> watchProfile({
    required BusinessContext context,
    required String registerId,
  }) {
    final query = _database.select(_database.registers)
      ..where(
        (row) =>
            row.id.equals(registerId) &
            row.organizationId.equals(context.organizationId) &
            row.branchId.equals(context.branchId) &
            row.deletedAt.isNull(),
      );
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _profile(row),
    );
  }

  @override
  Future<RegisterHardwareProfile?> getProfile({
    required String organizationId,
    required String branchId,
    required String registerId,
  }) async {
    final row =
        await (_database.select(_database.registers)..where(
              (candidate) =>
                  candidate.id.equals(registerId) &
                  candidate.organizationId.equals(organizationId) &
                  candidate.branchId.equals(branchId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _profile(row);
  }

  @override
  Future<RegisterHardwareProfile?> getProfileForDevice({
    required String organizationId,
    required String branchId,
    required String deviceId,
  }) async {
    final row =
        await (_database.select(_database.registers)..where(
              (candidate) =>
                  candidate.organizationId.equals(organizationId) &
                  candidate.branchId.equals(branchId) &
                  candidate.assignedDeviceId.equals(deviceId) &
                  candidate.isActive.equals(true) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _profile(row);
  }

  @override
  Future<Result<void, Failure>> configureProfile({
    required BusinessContext context,
    required RegisterHardwareProfileDraft draft,
  }) async {
    final validation = _validateProfile(draft);
    if (validation != null) return Result.failure(validation);
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    final payload = <String, Object?>{
      'registerId': draft.registerId,
      'scannerType': draft.scannerType.databaseValue,
      'scannerInterCharacterTimeoutMs': draft.scannerInterCharacterTimeoutMs,
      'scannerDuplicateSuppressionMs': draft.scannerDuplicateSuppressionMs,
      'printerType': draft.printerType.databaseValue,
      'printerAddress': _trimmedOrNull(draft.printerAddress),
      'printerPort': draft.printerPort,
      'printerPaperWidthMm': draft.printerPaperWidthMm,
      'cashDrawerEnabled': draft.cashDrawerEnabled,
      'cashDrawerPin': draft.cashDrawerPin,
      'expectedVersion': draft.expectedVersion,
    };
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final updated =
            await (database.update(database.registers)..where(
                  (row) =>
                      row.id.equals(draft.registerId) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.version.equals(draft.expectedVersion) &
                      row.isActive.equals(true) &
                      row.deletedAt.isNull(),
                ))
                .write(
                  db.RegistersCompanion(
                    scannerType: Value(draft.scannerType.databaseValue),
                    scannerInterCharacterTimeoutMs: Value(
                      draft.scannerInterCharacterTimeoutMs,
                    ),
                    scannerDuplicateSuppressionMs: Value(
                      draft.scannerDuplicateSuppressionMs,
                    ),
                    printerType: Value(draft.printerType.databaseValue),
                    printerAddress: Value(_trimmedOrNull(draft.printerAddress)),
                    printerPort: Value(draft.printerPort),
                    printerPaperWidthMm: Value(draft.printerPaperWidthMm),
                    cashDrawerEnabled: Value(draft.cashDrawerEnabled),
                    cashDrawerPin: Value(draft.cashDrawerPin),
                    version: Value(draft.expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const ConflictFailure(
            'The register hardware configuration changed. Refresh and retry.',
          );
        }
      },
      auditEntry: AuditLogEntry(
        id: _idGenerator.newId(),
        operationId: operationId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        actionType: AuditActionType.update,
        entityName: 'register_hardware',
        entityId: draft.registerId,
        metadata: payload,
        createdAt: now,
      ),
      outboxCommand: OutboxCommand(
        operationId: operationId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        commandType: 'register.hardware.configure',
        aggregateType: 'register',
        aggregateId: draft.registerId,
        payload: payload,
        createdAt: now,
      ),
    );
  }

  @override
  Future<Result<domain.ReceiptPrintJob?, Failure>> enqueueReceipt({
    required BusinessContext context,
    required domain.ReceiptPrintRequest request,
  }) async {
    final now = _clock.nowUtc();
    final jobId = _idGenerator.newId();
    final deduplicationKey = request.copyType == domain.ReceiptCopyType.original
        ? 'original:${context.organizationId}:${request.saleId}'
        : 'reprint:$jobId';
    final companion = db.ReceiptPrintJobsCompanion.insert(
      id: jobId,
      organizationId: context.organizationId,
      branchId: context.branchId,
      registerId: request.registerId,
      saleId: request.saleId,
      deduplicationKey: deduplicationKey,
      copyType: request.copyType.databaseValue,
      documentText: request.documentText,
      requestedByUserId: context.actorUserId,
      createdAt: now,
      updatedAt: now,
    );
    if (request.copyType == domain.ReceiptCopyType.reprint) {
      final result = await _localMutationTransaction.execute(
        businessWrite: (database) async {
          await database.into(database.receiptPrintJobs).insert(companion);
        },
        auditEntry: AuditLogEntry(
          id: _idGenerator.newId(),
          operationId: jobId,
          organizationId: context.organizationId,
          branchId: context.branchId,
          actorUserId: context.actorUserId,
          actionType: AuditActionType.sale,
          entityName: 'sale_receipt_reprint',
          entityId: request.saleId,
          metadata: {
            'printJobId': jobId,
            'registerId': request.registerId,
            'copyType': request.copyType.databaseValue,
          },
          createdAt: now,
        ),
        outboxCommand: OutboxCommand(
          operationId: jobId,
          organizationId: context.organizationId,
          branchId: context.branchId,
          actorUserId: context.actorUserId,
          commandType: 'receipt.reprint',
          aggregateType: 'receipt_reprint_event',
          aggregateId: jobId,
          payload: {
            'id': jobId,
            'saleId': request.saleId,
            'registerId': request.registerId,
            'requestedAt': now.toIso8601String(),
          },
          createdAt: now,
        ),
      );
      if (result case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
    } else {
      try {
        final existing =
            await (_database.select(_database.receiptPrintJobs)..where(
                  (row) => row.deduplicationKey.equals(deduplicationKey),
                ))
                .getSingleOrNull();
        if (existing != null) return Result.success(_job(existing));
        await _database.into(_database.receiptPrintJobs).insert(companion);
      } catch (error, stackTrace) {
        return Result.failure(
          DatabaseFailure(
            'The receipt print job could not be queued.',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    final row = await (_database.select(
      _database.receiptPrintJobs,
    )..where((candidate) => candidate.id.equals(jobId))).getSingle();
    return Result.success(_job(row));
  }

  @override
  Future<List<domain.ReceiptPrintJob>> claimDueJobs({
    required DateTime now,
    int limit = 10,
  }) {
    return _database.transaction(() async {
      final query = _database.select(_database.receiptPrintJobs)
        ..where(
          (row) =>
              row.status.isIn([
                domain.ReceiptPrintJobStatus.pending.databaseValue,
                domain.ReceiptPrintJobStatus.retryableFailure.databaseValue,
              ]) &
              (row.nextAttemptAt.isNull() |
                  row.nextAttemptAt.isSmallerOrEqualValue(now)),
        )
        ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
        ..limit(limit);
      final rows = await query.get();
      for (final row in rows) {
        await (_database.update(
          _database.receiptPrintJobs,
        )..where((candidate) => candidate.id.equals(row.id))).write(
          db.ReceiptPrintJobsCompanion(
            status: Value(
              domain.ReceiptPrintJobStatus.processing.databaseValue,
            ),
            updatedAt: Value(now),
          ),
        );
      }
      return rows
          .map(
            (row) => _job(
              row.copyWith(
                status: domain.ReceiptPrintJobStatus.processing.databaseValue,
                updatedAt: now,
              ),
            ),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<void> markPrintSucceeded({
    required String jobId,
    required DateTime printedAt,
  }) async {
    await (_database.update(
      _database.receiptPrintJobs,
    )..where((row) => row.id.equals(jobId))).write(
      db.ReceiptPrintJobsCompanion(
        status: Value(domain.ReceiptPrintJobStatus.succeeded.databaseValue),
        nextAttemptAt: const Value(null),
        lastError: const Value(null),
        printedAt: Value(printedAt),
        updatedAt: Value(printedAt),
      ),
    );
  }

  @override
  Future<void> markPrintFailed({
    required String jobId,
    required int attemptCount,
    required String error,
    required DateTime failedAt,
    required DateTime? nextAttemptAt,
  }) async {
    final status = nextAttemptAt == null
        ? domain.ReceiptPrintJobStatus.permanentFailure
        : domain.ReceiptPrintJobStatus.retryableFailure;
    await (_database.update(
      _database.receiptPrintJobs,
    )..where((row) => row.id.equals(jobId))).write(
      db.ReceiptPrintJobsCompanion(
        status: Value(status.databaseValue),
        attemptCount: Value(attemptCount),
        nextAttemptAt: Value(nextAttemptAt),
        lastError: Value(error),
        updatedAt: Value(failedAt),
      ),
    );
  }

  @override
  Future<void> recoverInterruptedJobs({required DateTime now}) async {
    await (_database.update(_database.receiptPrintJobs)..where(
          (row) => row.status.equals(
            domain.ReceiptPrintJobStatus.processing.databaseValue,
          ),
        ))
        .write(
          db.ReceiptPrintJobsCompanion(
            status: Value(
              domain.ReceiptPrintJobStatus.retryableFailure.databaseValue,
            ),
            nextAttemptAt: Value(now),
            lastError: const Value(
              'Recovered interrupted print job after application restart.',
            ),
            updatedAt: Value(now),
          ),
        );
  }

  RegisterHardwareProfile _profile(db.Register row) {
    return RegisterHardwareProfile(
      registerId: row.id,
      scannerType: BarcodeScannerType.fromDatabase(row.scannerType),
      scannerInterCharacterTimeoutMs: row.scannerInterCharacterTimeoutMs,
      scannerDuplicateSuppressionMs: row.scannerDuplicateSuppressionMs,
      printerType: ReceiptPrinterType.fromDatabase(row.printerType),
      printerAddress: row.printerAddress,
      printerPort: row.printerPort,
      printerPaperWidthMm: row.printerPaperWidthMm,
      cashDrawerEnabled: row.cashDrawerEnabled,
      cashDrawerPin: row.cashDrawerPin,
      version: row.version,
    );
  }

  domain.ReceiptPrintJob _job(db.ReceiptPrintJob row) {
    return domain.ReceiptPrintJob(
      id: row.id,
      organizationId: row.organizationId,
      branchId: row.branchId,
      registerId: row.registerId,
      saleId: row.saleId,
      copyType: domain.ReceiptCopyType.fromDatabase(row.copyType),
      documentText: row.documentText,
      status: domain.ReceiptPrintJobStatus.fromDatabase(row.status),
      attemptCount: row.attemptCount,
      nextAttemptAt: row.nextAttemptAt,
      lastError: row.lastError,
      requestedByUserId: row.requestedByUserId,
      printedAt: row.printedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

ValidationFailure? _validateProfile(RegisterHardwareProfileDraft draft) {
  if (draft.scannerInterCharacterTimeoutMs < 20 ||
      draft.scannerInterCharacterTimeoutMs > 1000) {
    return const ValidationFailure(
      'Scanner character timeout must be between 20 and 1000 milliseconds.',
    );
  }
  if (draft.scannerDuplicateSuppressionMs < 0 ||
      draft.scannerDuplicateSuppressionMs > 5000) {
    return const ValidationFailure(
      'Scanner duplicate suppression must be between 0 and 5000 milliseconds.',
    );
  }
  if (draft.printerPort < 1 || draft.printerPort > 65535) {
    return const ValidationFailure('Printer port must be between 1 and 65535.');
  }
  if (draft.printerPaperWidthMm != 58 && draft.printerPaperWidthMm != 80) {
    return const ValidationFailure('Printer paper width must be 58 or 80 mm.');
  }
  if (draft.cashDrawerPin != 0 && draft.cashDrawerPin != 1) {
    return const ValidationFailure('Cash drawer pin must be 0 or 1.');
  }
  if (draft.printerType == ReceiptPrinterType.networkEscPos &&
      _trimmedOrNull(draft.printerAddress) == null) {
    return const ValidationFailure('Enter the network printer address.');
  }
  if (draft.cashDrawerEnabled &&
      draft.printerType != ReceiptPrinterType.networkEscPos) {
    return const ValidationFailure(
      'The cash drawer requires a configured network ESC/POS printer.',
    );
  }
  return null;
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
