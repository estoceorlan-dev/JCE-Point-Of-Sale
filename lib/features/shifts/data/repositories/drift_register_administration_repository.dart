import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' hide Register;
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/register.dart';
import '../../domain/repositories/register_administration_repository.dart';

class DriftRegisterAdministrationRepository
    implements RegisterAdministrationRepository {
  const DriftRegisterAdministrationRepository({
    required AppDatabase database,
    required IdGenerator ids,
    required AppClock clock,
  }) : _database = database,
       _ids = ids,
       _clock = clock;
  final AppDatabase _database;
  final IdGenerator _ids;
  final AppClock _clock;

  @override
  Stream<List<Register>> watchAll(BusinessContext context) =>
      (_database.select(_database.registers)
            ..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId),
            )
            ..orderBy([
              (row) => OrderingTerm.desc(row.isActive),
              (row) => OrderingTerm.asc(row.name),
            ]))
          .watch()
          .map(
            (rows) => rows
                .map(
                  (row) => Register(
                    id: row.id,
                    organizationId: row.organizationId,
                    branchId: row.branchId,
                    code: row.code,
                    name: row.name,
                    isActive: row.isActive && row.deletedAt == null,
                    version: row.version,
                    assignedDeviceId: row.assignedDeviceId,
                  ),
                )
                .toList(growable: false),
          );

  @override
  Future<Result<void, Failure>> mutate({
    required BusinessContext context,
    required Register register,
    required RegisterAction action,
    RegisterDraft? draft,
  }) {
    final operationId = _ids.newId();
    final now = _clock.nowUtc();
    final command = switch (action) {
      RegisterAction.edit => 'register.update',
      RegisterAction.archive => 'register.archive',
      RegisterAction.restore => 'register.restore',
      RegisterAction.unassignDevice => 'register.unassign_device',
    };
    final payload = <String, Object?>{
      'registerId': register.id,
      'expectedVersion': register.version,
      if (draft != null) 'code': draft.code,
      if (draft != null) 'name': draft.name,
    };
    return LocalMutationTransaction(_database).execute(
      businessWrite: (database) async {
        final row =
            await (database.select(database.registers)..where(
                  (row) =>
                      row.id.equals(register.id) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId),
                ))
                .getSingleOrNull();
        if (row == null || row.version != register.version) {
          throw const ConflictFailure(
            'The register changed. Refresh and retry.',
          );
        }
        if (action != RegisterAction.restore && !row.isActive) {
          throw const ValidationFailure('Restore this register first.');
        }
        if (action == RegisterAction.archive ||
            action == RegisterAction.unassignDevice) {
          final open =
              await (database.select(database.shifts)
                    ..where(
                      (shift) =>
                          shift.registerId.equals(register.id) &
                          shift.organizationId.equals(context.organizationId) &
                          shift.status.equals('open'),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (open != null) {
            throw const ConflictFailure('Close the register’s shift first.');
          }
        }
        if (action == RegisterAction.edit) {
          if (draft == null) {
            throw const ValidationFailure('Register details are required.');
          }
          final duplicate =
              await (database.select(database.registers)
                    ..where(
                      (other) =>
                          other.organizationId.equals(context.organizationId) &
                          other.branchId.equals(context.branchId) &
                          other.code.upper().equals(draft.code) &
                          other.id.equals(register.id).not(),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (duplicate != null) {
            throw const ConflictFailure('This register code already exists.');
          }
        }
        final unassign =
            action == RegisterAction.archive ||
            action == RegisterAction.unassignDevice;
        await (database.update(
          database.registers,
        )..where((value) => value.id.equals(register.id))).write(
          RegistersCompanion(
            code: draft == null ? const Value.absent() : Value(draft.code),
            name: draft == null ? const Value.absent() : Value(draft.name),
            isActive: action == RegisterAction.archive
                ? const Value(false)
                : action == RegisterAction.restore
                ? const Value(true)
                : const Value.absent(),
            deletedAt: action == RegisterAction.archive
                ? Value(now)
                : action == RegisterAction.restore
                ? const Value(null)
                : const Value.absent(),
            assignedDeviceId: unassign
                ? const Value(null)
                : const Value.absent(),
            assignedByUserId: unassign
                ? const Value(null)
                : const Value.absent(),
            assignedAt: unassign ? const Value(null) : const Value.absent(),
            version: Value(row.version + 1),
            updatedAt: Value(now),
          ),
        );
      },
      auditEntry: AuditLogEntry(
        id: _ids.newId(),
        operationId: operationId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        actionType: action == RegisterAction.archive
            ? AuditActionType.delete
            : AuditActionType.update,
        entityName: 'register',
        entityId: register.id,
        metadata: {'action': action.name, ...payload},
        createdAt: now,
      ),
      outboxCommand: OutboxCommand(
        operationId: operationId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        commandType: command,
        aggregateType: 'register',
        aggregateId: register.id,
        payload: payload,
        createdAt: now,
      ),
    );
  }
}
