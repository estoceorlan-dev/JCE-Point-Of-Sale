import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/settings/data/repositories/drift_settings_repository.dart';
import 'package:jce_pos/features/settings/domain/entities/operational_setting.dart';
import 'package:jce_pos/features/settings/domain/entities/reason_code.dart';
import 'package:jce_pos/shared/models/audit_log_entry.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  group('Phase 14 audit and settings', () {
    late AppDatabase database;
    late DriftSettingsRepository repository;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(database);
      repository = DriftSettingsRepository(
        database: database,
        localMutationTransaction: LocalMutationTransaction(database),
        idGenerator: _SequenceIdGenerator(),
        clock: FixedAppClock(DateTime.utc(2026, 9, 2, 9)),
      );
    });

    tearDown(() => database.close());

    test(
      'branch settings override organization defaults and can inherit again',
      () async {
        final organization = await repository.saveSetting(
          context: _context,
          scope: SettingScope.organization,
          key: OperationalSettingKey.inventoryAllowNegativeStock,
          value: true,
          operationId: 'organization-setting',
        );
        expect(
          organization.isSuccess,
          isTrue,
          reason:
              '${organization.failureOrNull?.message}: '
              '${organization.failureOrNull?.cause}',
        );
        var settings = await repository
            .watchResolvedSettings(context: _context)
            .first;
        expect(
          settings.boolean(OperationalSettingKey.inventoryAllowNegativeStock),
          isTrue,
        );
        expect(
          settings[OperationalSettingKey.inventoryAllowNegativeStock].origin,
          SettingOrigin.organization,
        );

        final branch = await repository.saveSetting(
          context: _context,
          scope: SettingScope.branch,
          key: OperationalSettingKey.inventoryAllowNegativeStock,
          value: false,
          operationId: 'branch-setting',
        );
        expect(branch.isSuccess, isTrue, reason: branch.failureOrNull?.message);
        settings = await repository
            .watchResolvedSettings(context: _context)
            .first;
        expect(
          settings.boolean(OperationalSettingKey.inventoryAllowNegativeStock),
          isFalse,
        );
        expect(
          settings[OperationalSettingKey.inventoryAllowNegativeStock].origin,
          SettingOrigin.branch,
        );
        expect(
          (await (database.select(
                database.branches,
              )..where((row) => row.id.equals('branch'))).getSingle())
              .allowNegativeStock,
          isFalse,
        );

        final inherited = await repository.clearBranchOverride(
          context: _context,
          key: OperationalSettingKey.inventoryAllowNegativeStock,
          operationId: 'clear-setting',
        );
        expect(
          inherited.isSuccess,
          isTrue,
          reason: inherited.failureOrNull?.message,
        );
        settings = await repository
            .watchResolvedSettings(context: _context)
            .first;
        expect(
          settings.boolean(OperationalSettingKey.inventoryAllowNegativeStock),
          isTrue,
        );
        expect(
          (await (database.select(
                database.branches,
              )..where((row) => row.id.equals('branch'))).getSingle())
              .allowNegativeStock,
          isTrue,
        );
        expect(
          await database.select(database.syncOutboxEntries).get(),
          hasLength(3),
        );
        expect(
          await database.select(database.localAuditLogs).get(),
          hasLength(3),
        );
      },
    );

    test(
      'cached settings remain readable without a remote dependency',
      () async {
        await repository.saveSetting(
          context: _context,
          scope: SettingScope.branch,
          key: OperationalSettingKey.receiptFooter,
          value: 'Salamat!',
          operationId: 'receipt-footer',
        );

        final reopenedRepository = DriftSettingsRepository(
          database: database,
          localMutationTransaction: LocalMutationTransaction(database),
          idGenerator: _SequenceIdGenerator(),
          clock: FixedAppClock(DateTime.utc(2026, 9, 2, 10)),
        );
        final settings = await reopenedRepository
            .watchResolvedSettings(context: _context)
            .first;

        expect(settings.text(OperationalSettingKey.receiptFooter), 'Salamat!');
        expect(
          settings[OperationalSettingKey.receiptFooter].origin,
          SettingOrigin.branch,
        );
      },
    );

    test('reason codes are scoped, versioned, audited, and queued', () async {
      final organization = await repository.saveReasonCode(
        context: _context,
        draft: const ReasonCodeDraft(
          category: ReasonCodeCategory.inventoryAdjustment,
          code: 'DAMAGED',
          label: 'Damaged stock',
          requiresNote: true,
          scope: SettingScope.organization,
          operationId: 'reason-organization',
        ),
      );
      final branch = await repository.saveReasonCode(
        context: _context,
        draft: const ReasonCodeDraft(
          category: ReasonCodeCategory.inventoryAdjustment,
          code: 'DAMAGED',
          label: 'Branch damaged stock',
          requiresNote: false,
          scope: SettingScope.branch,
          operationId: 'reason-branch',
        ),
      );

      expect(
        organization.isSuccess,
        isTrue,
        reason:
            '${organization.failureOrNull?.message}: '
            '${organization.failureOrNull?.cause}',
      );
      expect(branch.isSuccess, isTrue, reason: branch.failureOrNull?.message);
      final effective = await repository
          .watchReasonCodes(context: _context)
          .first;
      expect(effective, hasLength(1));
      expect(effective.single.label, 'Branch damaged stock');
      expect(effective.single.scope, SettingScope.branch);
      expect(
        (await database.select(database.syncOutboxEntries).get()).map(
          (entry) => entry.commandType,
        ),
        everyElement('reason_code.upsert'),
      );
    });

    test(
      'audit metadata is sanitized, device-attributed, and immutable',
      () async {
        await database.metadataDao.writeValue(
          key: 'device.id',
          value: 'device-14',
          updatedAt: DateTime.utc(2026, 9, 2),
        );
        await database.auditLogDao.append(
          AuditLogEntry(
            id: 'sensitive-audit',
            organizationId: _context.organizationId,
            actorUserId: _context.actorUserId,
            branchId: _context.branchId,
            actionType: AuditActionType.update,
            entityName: 'payment_configuration',
            entityId: 'payment-1',
            metadata: const {
              'safe': 'visible',
              'password': 'never-store-me',
              'nested': {'accessToken': 'also-secret'},
            },
            createdAt: DateTime.utc(2026, 9, 2),
          ),
        );

        final row = await database.select(database.localAuditLogs).getSingle();
        final metadata = jsonDecode(row.metadataJson) as Map<String, dynamic>;
        expect(row.deviceId, 'device-14');
        expect(metadata['safe'], 'visible');
        expect(metadata['password'], '[REDACTED]');
        expect(
          (metadata['nested'] as Map<String, dynamic>)['accessToken'],
          '[REDACTED]',
        );
        await expectLater(
          database.customUpdate(
            "UPDATE local_audit_logs SET entity_id = 'changed' WHERE id = 'sensitive-audit'",
          ),
          throwsA(anything),
        );
        await expectLater(
          database.customUpdate(
            "DELETE FROM local_audit_logs WHERE id = 'sensitive-audit'",
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'audit filters preserve branch scope and include organization events',
      () async {
        for (final entry in [
          _audit('organization-event', null, AuditActionType.settingChange),
          _audit('branch-event', 'branch', AuditActionType.sale),
          _audit('other-branch-event', 'branch-2', AuditActionType.sale),
        ]) {
          await database.auditLogDao.append(entry);
        }

        final rows = await database.auditLogDao
            .watchEntries(
              organizationId: 'organization',
              branchId: 'branch',
              actionType: AuditActionType.sale,
              search: 'branch-event',
            )
            .first;

        expect(rows.map((entry) => entry.id), ['branch-event']);
      },
    );
  });
}

const _context = BusinessContext(
  organizationId: 'organization',
  branchId: 'branch',
  actorUserId: 'user',
);

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.utc(2026, 9, 2);
  await database
      .into(database.organizations)
      .insert(
        OrganizationsCompanion.insert(
          id: 'organization',
          code: 'JCE',
          name: 'JCE',
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final id in ['branch', 'branch-2']) {
    await database
        .into(database.branches)
        .insert(
          BranchesCompanion.insert(
            id: id,
            organizationId: 'organization',
            code: id.toUpperCase(),
            name: id,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
  await database
      .into(database.appUsers)
      .insert(
        AppUsersCompanion.insert(
          id: 'user',
          organizationId: 'organization',
          email: 'admin@jce.test',
          displayName: 'Administrator',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

AuditLogEntry _audit(String id, String? branchId, AuditActionType action) =>
    AuditLogEntry(
      id: id,
      organizationId: 'organization',
      actorUserId: 'user',
      branchId: branchId,
      actionType: action,
      entityName: 'sale',
      entityId: id,
      createdAt: DateTime.utc(2026, 9, 2),
    );

class _SequenceIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String newId() => 'generated-${_value++}';
}
