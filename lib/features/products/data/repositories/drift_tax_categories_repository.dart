import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/catalog_drafts.dart';
import '../../domain/repositories/tax_categories_repository.dart';

class DriftTaxCategoriesRepository implements TaxCategoriesRepository {
  const DriftTaxCategoriesRepository({
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
  Future<Result<String, Failure>> save({
    required BusinessContext context,
    required TaxCategoryDraft draft,
    String? id,
  }) async {
    final value = draft.normalized();
    final recordId = id ?? _ids.newId();
    final now = _clock.nowUtc();
    return _mutate(
      context,
      recordId,
      id == null ? 'create' : 'update',
      {
        'id': recordId,
        'code': value.code,
        'name': value.name,
        'rateBasisPoints': value.rateBasisPoints,
        'isInclusive': value.isInclusive,
      },
      (database) async {
        final duplicate =
            await (database.select(database.taxCategories)
                  ..where(
                    (row) =>
                        row.organizationId.equals(context.organizationId) &
                        row.code.upper().equals(value.code) &
                        row.id.equals(recordId).not(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (duplicate != null) {
          throw const ConflictFailure('This tax code already exists.');
        }
        if (id == null) {
          await database
              .into(database.taxCategories)
              .insert(
                TaxCategoriesCompanion.insert(
                  id: recordId,
                  organizationId: context.organizationId,
                  code: value.code,
                  name: value.name,
                  rateBasisPoints: value.rateBasisPoints,
                  isInclusive: Value(value.isInclusive),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        } else {
          final changed =
              await (database.update(database.taxCategories)..where(
                    (row) =>
                        row.id.equals(recordId) &
                        row.organizationId.equals(context.organizationId) &
                        row.deletedAt.isNull(),
                  ))
                  .write(
                    TaxCategoriesCompanion(
                      code: Value(value.code),
                      name: Value(value.name),
                      rateBasisPoints: Value(value.rateBasisPoints),
                      isInclusive: Value(value.isInclusive),
                      updatedAt: Value(now),
                    ),
                  );
          if (changed != 1) {
            throw const ValidationFailure(
              'Restore this tax category before editing it.',
            );
          }
        }
        return recordId;
      },
    );
  }

  @override
  Future<Result<void, Failure>> setArchived({
    required BusinessContext context,
    required String id,
    required bool archived,
  }) => _mutate(context, id, archived ? 'archive' : 'restore', {'id': id}, (
    database,
  ) async {
    final now = _clock.nowUtc();
    final changed =
        await (database.update(database.taxCategories)..where(
              (row) =>
                  row.id.equals(id) &
                  row.organizationId.equals(context.organizationId),
            ))
            .write(
              TaxCategoriesCompanion(
                isActive: Value(!archived),
                deletedAt: Value(archived ? now : null),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) {
      throw const ValidationFailure('This tax category is unavailable.');
    }
  });

  Future<Result<T, Failure>> _mutate<T>(
    BusinessContext context,
    String id,
    String action,
    Map<String, Object?> payload,
    Future<T> Function(AppDatabase) write,
  ) {
    final operationId = _ids.newId();
    final now = _clock.nowUtc();
    return LocalMutationTransaction(_database).execute(
      businessWrite: write,
      auditEntry: AuditLogEntry(
        id: _ids.newId(),
        operationId: operationId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        actionType: action == 'create'
            ? AuditActionType.create
            : action == 'archive'
            ? AuditActionType.delete
            : AuditActionType.update,
        entityName: 'tax_category',
        entityId: id,
        metadata: payload,
        createdAt: now,
      ),
      outboxCommand: OutboxCommand(
        operationId: operationId,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        commandType: 'tax_category.$action',
        aggregateType: 'tax_category',
        aggregateId: id,
        payload: payload,
        createdAt: now,
      ),
    );
  }
}
