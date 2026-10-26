import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/database/models/outbox_command.dart';
import 'package:jce_pos/shared/models/audit_log_entry.dart';
import 'package:jce_pos/core/error/failures.dart';

void main() {
  late AppDatabase database;
  late LocalMutationTransaction mutation;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mutation = LocalMutationTransaction(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'business write, audit entry, and outbox command commit together',
    () async {
      final now = DateTime.utc(2026, 1, 1);

      final result = await mutation.execute<String>(
        businessWrite: (db) async {
          await db
              .into(db.organizations)
              .insert(
                OrganizationsCompanion.insert(
                  id: 'org-1',
                  code: 'JCE',
                  name: 'JCE',
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          return 'org-1';
        },
        auditEntry: AuditLogEntry(
          id: 'audit-1',
          operationId: 'operation-1',
          organizationId: 'org-1',
          actorUserId: 'user-1',
          actionType: AuditActionType.create,
          entityName: 'organization',
          entityId: 'org-1',
          createdAt: now,
        ),
        outboxCommand: OutboxCommand(
          operationId: 'operation-1',
          organizationId: 'org-1',
          commandType: 'create_organization',
          aggregateType: 'organization',
          aggregateId: 'org-1',
          payload: const {'name': 'JCE'},
          createdAt: now,
        ),
      );

      expect(result.valueOrNull, 'org-1');
      expect(await database.select(database.organizations).get(), hasLength(1));
      expect(
        await database.select(database.localAuditLogs).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.syncOutboxEntries).get(),
        hasLength(1),
      );
    },
  );

  test('failed online precondition prevents every local write', () async {
    final guarded = LocalMutationTransaction(
      database,
      precondition: () async => const NetworkFailure('Online required.'),
    );
    final now = DateTime.utc(2026, 1, 1);
    final result = await guarded.execute<void>(
      businessWrite: (db) async {
        await db.into(db.organizations).insert(
              OrganizationsCompanion.insert(
                id: 'org-1',
                code: 'JCE',
                name: 'JCE',
                createdAt: now,
                updatedAt: now,
              ),
            );
      },
      auditEntry: AuditLogEntry(
        id: 'audit-1',
        operationId: 'operation-1',
        organizationId: 'org-1',
        actorUserId: 'user-1',
        actionType: AuditActionType.create,
        entityName: 'organization',
        entityId: 'org-1',
        createdAt: now,
      ),
      outboxCommand: OutboxCommand(
        operationId: 'operation-1',
        organizationId: 'org-1',
        commandType: 'create_organization',
        aggregateType: 'organization',
        aggregateId: 'org-1',
        payload: const {},
        createdAt: now,
      ),
    );

    expect(result.isFailure, isTrue);
    expect(await database.select(database.organizations).get(), isEmpty);
    expect(await database.select(database.localAuditLogs).get(), isEmpty);
    expect(await database.select(database.syncOutboxEntries).get(), isEmpty);
  });

  test(
    'failed business write rolls back business, audit, and outbox records',
    () async {
      final now = DateTime.utc(2026, 1, 1);

      final result = await mutation.execute<void>(
        businessWrite: (db) async {
          await db
              .into(db.organizations)
              .insert(
                OrganizationsCompanion.insert(
                  id: 'org-1',
                  code: 'JCE',
                  name: 'JCE',
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          throw StateError('Simulated failure.');
        },
        auditEntry: AuditLogEntry(
          id: 'audit-1',
          operationId: 'operation-1',
          organizationId: 'org-1',
          actorUserId: 'user-1',
          actionType: AuditActionType.create,
          entityName: 'organization',
          entityId: 'org-1',
          createdAt: now,
        ),
        outboxCommand: OutboxCommand(
          operationId: 'operation-1',
          organizationId: 'org-1',
          commandType: 'create_organization',
          aggregateType: 'organization',
          aggregateId: 'org-1',
          payload: const {'name': 'JCE'},
          createdAt: now,
        ),
      );

      expect(result.isFailure, isTrue);
      expect(await database.select(database.organizations).get(), isEmpty);
      expect(await database.select(database.localAuditLogs).get(), isEmpty);
      expect(await database.select(database.syncOutboxEntries).get(), isEmpty);
    },
  );
}
