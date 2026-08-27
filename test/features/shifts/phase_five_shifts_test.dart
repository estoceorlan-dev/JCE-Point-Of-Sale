import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/auth/domain/usecases/require_permission_usecase.dart';
import 'package:jce_pos/features/shifts/data/data_sources/shift_local_data_source.dart';
import 'package:jce_pos/features/shifts/data/repositories/drift_shift_repository.dart';
import 'package:jce_pos/features/shifts/domain/entities/cash_movement.dart';
import 'package:jce_pos/features/shifts/domain/entities/cash_shift.dart';
import 'package:jce_pos/features/shifts/domain/use_cases/open_shift_use_case.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart' as domain_user;
import 'package:jce_pos/shared/models/branch.dart' as domain;
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/business_context.dart';
import 'package:jce_pos/shared/models/organization.dart' as domain_org;
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  late AppDatabase database;
  late DriftShiftRepository repository;

  const context = BusinessContext(
    organizationId: 'organization',
    branchId: 'branch',
    actorUserId: 'cashier-user',
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = _repository(database);
    await _seedContext(database);
  });

  tearDown(() => database.close());

  test('duplicate user shifts follow branch policy', () async {
    final first = await repository.openShift(
      context: context,
      draft: const OpenShiftDraft(
        registerId: 'register-a',
        deviceId: 'device-a',
        openingCashMinor: 10000,
        operationId: 'open-a',
      ),
    );
    final denied = await repository.openShift(
      context: context,
      draft: const OpenShiftDraft(
        registerId: 'register-b',
        deviceId: 'device-b',
        openingCashMinor: 5000,
        operationId: 'open-b-denied',
      ),
    );

    expect(first.isSuccess, isTrue);
    expect(denied.failureOrNull, isA<ConflictFailure>());

    await repository.configurePolicy(
      context: context,
      policy: const ShiftPolicy(
        allowMultipleOpenShiftsPerUser: true,
        allowSalesWithoutOpenShift: false,
      ),
    );
    final allowed = await repository.openShift(
      context: context,
      draft: const OpenShiftDraft(
        registerId: 'register-b',
        deviceId: 'device-b',
        openingCashMinor: 5000,
        operationId: 'open-b-allowed',
      ),
    );

    expect(allowed.isSuccess, isTrue);
    expect(
      await (database.select(
        database.shifts,
      )..where((row) => row.status.equals('open'))).get(),
      hasLength(2),
    );
  });

  test(
    'opening and closing balances remain exact integer minor units',
    () async {
      final opened = await _open(repository, openingCashMinor: 12345);
      final closed = await repository.closeShift(
        context: context,
        draft: CloseShiftDraft(
          shiftId: opened,
          countedAmountsMinor: _counts(cash: 12345),
          expectedVersion: 0,
          operationId: 'close-exact',
        ),
      );

      final shift = await database.select(database.shifts).getSingle();
      final counts = await database.select(database.shiftCounts).get();
      expect(closed.isSuccess, isTrue);
      expect(shift.openingCashMinor, 12345);
      expect(shift.expectedCashMinor, 12345);
      expect(shift.countedCashMinor, 12345);
      expect(shift.discrepancyMinor, 0);
      expect(counts, hasLength(3));
      expect(counts.every((count) => count.discrepancyMinor == 0), isTrue);
    },
  );

  test('immutable cash movements reproduce expected drawer cash', () async {
    final shiftId = await _open(repository, openingCashMinor: 10000);
    for (final movement in const [
      CashMovementDraft(
        shiftId: 'placeholder',
        type: CashMovementType.cashIn,
        amountMinor: 2500,
        reason: 'Change fund top-up',
        operationId: 'cash-in',
      ),
      CashMovementDraft(
        shiftId: 'placeholder',
        type: CashMovementType.cashOut,
        amountMinor: -1000,
        reason: 'Safe drop',
        operationId: 'cash-out',
      ),
      CashMovementDraft(
        shiftId: 'placeholder',
        type: CashMovementType.payout,
        amountMinor: -500,
        reason: 'Courier fee',
        operationId: 'payout',
      ),
      CashMovementDraft(
        shiftId: 'placeholder',
        type: CashMovementType.correction,
        amountMinor: 200,
        reason: 'Opening recount',
        operationId: 'correction',
      ),
    ]) {
      final result = await repository.postCashMovement(
        context: context,
        draft: CashMovementDraft(
          shiftId: shiftId,
          type: movement.type,
          amountMinor: movement.amountMinor,
          reason: movement.reason,
          operationId: movement.operationId,
        ),
      );
      expect(result.isSuccess, isTrue);
    }

    final active = await repository
        .watchActiveShift(context: context, deviceId: 'device-a')
        .first;
    expect(active!.cashMovementTotalMinor, 1200);
    expect(active.expectedCashMinor, 11200);
    expect(await database.select(database.cashMovements).get(), hasLength(4));
  });

  test('the active shift survives an offline database restart', () async {
    await database.close();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'jce-phase-five-',
    );
    final file = File('${tempDirectory.path}${Platform.pathSeparator}shift.db');
    AppDatabase? reopened;
    try {
      final persistent = AppDatabase.forTesting(NativeDatabase(file));
      await _seedContext(persistent);
      final firstRepository = _repository(persistent);
      final shiftId = await _open(firstRepository, openingCashMinor: 6789);
      await persistent.close();

      reopened = AppDatabase.forTesting(NativeDatabase(file));
      final recovered = await _repository(
        reopened,
      ).watchActiveShift(context: context, deviceId: 'device-a').first;

      expect(recovered?.id, shiftId);
      expect(recovered?.openingCashMinor, 6789);
      expect(recovered?.status, CashShiftStatus.open);
    } finally {
      await reopened?.close();
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  });

  test('another user cannot close a cashier shift without approval', () async {
    final shiftId = await _open(repository, openingCashMinor: 5000);
    const otherUser = BusinessContext(
      organizationId: 'organization',
      branchId: 'branch',
      actorUserId: 'other-user',
    );

    final result = await repository.closeShift(
      context: otherUser,
      draft: CloseShiftDraft(
        shiftId: shiftId,
        countedAmountsMinor: _counts(cash: 5000),
        expectedVersion: 0,
        operationId: 'unauthorized-close',
      ),
    );

    expect(result.failureOrNull, isA<AuthorizationFailure>());
    expect(await database.select(database.shiftCounts).get(), isEmpty);
    expect((await database.select(database.shifts).getSingle()).status, 'open');
  });

  test('discrepancies above policy require and retain approval', () async {
    await repository.configurePolicy(
      context: context,
      policy: const ShiftPolicy(
        allowMultipleOpenShiftsPerUser: false,
        allowSalesWithoutOpenShift: false,
        cashDiscrepancyApprovalThresholdMinor: 100,
      ),
    );
    final shiftId = await _open(repository, openingCashMinor: 10000);
    final draft = CloseShiftDraft(
      shiftId: shiftId,
      countedAmountsMinor: _counts(cash: 9800),
      expectedVersion: 0,
      operationId: 'approved-close',
      approvalNotes: 'Verified against physical count.',
    );

    final denied = await repository.closeShift(context: context, draft: draft);
    final approved = await repository.closeShift(
      context: context,
      draft: draft,
      approvedByUserId: 'manager-user',
    );

    final shift = await database.select(database.shifts).getSingle();
    expect(denied.failureOrNull, isA<AuthorizationFailure>());
    expect(approved.isSuccess, isTrue);
    expect(shift.discrepancyMinor, -200);
    expect(shift.approvedByUserId, 'manager-user');
    expect(shift.approvalNotes, 'Verified against physical count.');
  });

  test(
    'sale guard requires a valid shift unless branch policy allows bypass',
    () async {
      final denied = await repository.requireOpenShiftForSale(
        context: context,
        deviceId: 'device-a',
      );
      expect(denied.failureOrNull, isA<AuthorizationFailure>());

      await repository.configurePolicy(
        context: context,
        policy: const ShiftPolicy(
          allowMultipleOpenShiftsPerUser: false,
          allowSalesWithoutOpenShift: true,
        ),
      );
      final allowed = await repository.requireOpenShiftForSale(
        context: context,
        deviceId: 'device-a',
      );
      expect(allowed.isSuccess, isTrue);
      expect(allowed.valueOrNull, isNull);
    },
  );

  test('users without sales permission cannot open a register', () async {
    final useCase = OpenShiftUseCase(
      repository: repository,
      requirePermission: const RequirePermissionUseCase(),
    );
    final result = await useCase(
      session: _session(const {AppPermission.viewDashboard}),
      draft: const OpenShiftDraft(
        registerId: 'register-a',
        deviceId: 'device-a',
        openingCashMinor: 0,
      ),
    );

    expect(result.failureOrNull, isA<AuthorizationFailure>());
    expect(await database.select(database.shifts).get(), isEmpty);
  });
}

DriftShiftRepository _repository(AppDatabase database) {
  return DriftShiftRepository(
    database: database,
    localDataSource: ShiftLocalDataSource(database),
    localMutationTransaction: LocalMutationTransaction(database),
    idGenerator: _SequenceIdGenerator(),
    clock: FixedAppClock(DateTime.utc(2026, 8, 24, 8)),
  );
}

Future<String> _open(
  DriftShiftRepository repository, {
  required int openingCashMinor,
}) async {
  final result = await repository.openShift(
    context: const BusinessContext(
      organizationId: 'organization',
      branchId: 'branch',
      actorUserId: 'cashier-user',
    ),
    draft: OpenShiftDraft(
      registerId: 'register-a',
      deviceId: 'device-a',
      openingCashMinor: openingCashMinor,
      operationId: 'open-$openingCashMinor',
    ),
  );
  expect(result.isSuccess, isTrue);
  return result.valueOrNull!;
}

Map<ShiftPaymentMethod, int> _counts({required int cash}) => {
  ShiftPaymentMethod.cash: cash,
  ShiftPaymentMethod.card: 0,
  ShiftPaymentMethod.eWallet: 0,
};

Future<void> _seedContext(AppDatabase database) async {
  final now = DateTime.utc(2026, 8, 24);
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
  await database
      .into(database.branches)
      .insert(
        BranchesCompanion.insert(
          id: 'branch',
          organizationId: 'organization',
          code: 'MAIN',
          name: 'Main Branch',
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final register in const [
    ('register-a', 'REG-A', 'Front register', 'device-a'),
    ('register-b', 'REG-B', 'Back register', 'device-b'),
  ]) {
    await database
        .into(database.registers)
        .insert(
          RegistersCompanion.insert(
            id: register.$1,
            organizationId: 'organization',
            branchId: 'branch',
            code: register.$2,
            name: register.$3,
            assignedDeviceId: Value(register.$4),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

AuthSession _session(Set<AppPermission> permissions) {
  final role = AccessRole(
    id: 'role',
    code: 'test',
    name: 'Test',
    permissions: permissions,
  );
  return AuthSession(
    user: domain_user.AppUser(
      firebaseUid: 'firebase-user',
      email: 'user@jce.test',
      displayName: 'Test User',
      organizations: [
        OrganizationAccess(
          appUserId: 'cashier-user',
          organization: const domain_org.Organization(
            id: 'organization',
            code: 'JCE',
            name: 'JCE',
            timezone: 'Asia/Manila',
          ),
          status: UserAccountStatus.active,
          organizationRoles: const [],
          branches: [
            BranchAccess(
              branch: const domain.Branch(
                id: 'branch',
                organizationId: 'organization',
                code: 'MAIN',
                name: 'Main Branch',
                timezone: 'Asia/Manila',
              ),
              roles: [role],
            ),
          ],
        ),
      ],
    ),
    activeOrganizationId: 'organization',
    activeBranchId: 'branch',
  );
}

class _SequenceIdGenerator implements IdGenerator {
  var _value = 0;

  @override
  String newId() => 'generated-${_value++}';
}
