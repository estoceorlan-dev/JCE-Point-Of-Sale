import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failure.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/error/result.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/auth/domain/usecases/require_permission_usecase.dart';
import 'package:jce_pos/features/hardware/data/adapters/keyboard_wedge_barcode_scanner.dart';
import 'package:jce_pos/features/hardware/data/repositories/drift_pos_hardware_repository.dart';
import 'package:jce_pos/features/hardware/data/services/receipt_print_queue_processor.dart';
import 'package:jce_pos/features/hardware/domain/entities/receipt_print_job.dart';
import 'package:jce_pos/features/hardware/domain/entities/register_hardware_profile.dart';
import 'package:jce_pos/features/hardware/domain/services/cash_drawer.dart';
import 'package:jce_pos/features/hardware/domain/services/receipt_printer.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_status.dart';
import 'package:jce_pos/features/pos/domain/services/receipt_pdf_generator.dart';
import 'package:jce_pos/features/pos/domain/services/receipt_renderer.dart';
import 'package:jce_pos/features/pos/domain/use_cases/deliver_sale_receipt_use_case.dart';
import 'package:jce_pos/features/pos/domain/use_cases/open_sale_cash_drawer_use_case.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart' as domain_user;
import 'package:jce_pos/shared/models/branch.dart' as domain_branch;
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/business_context.dart';
import 'package:jce_pos/shared/models/organization.dart' as domain_org;
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  group('keyboard-wedge scanner', () {
    test('terminator and duplicate suffix input emit one cart scan', () async {
      final scanner = KeyboardWedgeBarcodeScanner(
        interCharacterTimeout: const Duration(milliseconds: 80),
        duplicateSuppression: const Duration(milliseconds: 350),
      );
      final scans = <String>[];
      final subscription = scanner.scans.listen(
        (scan) => scans.add(scan.value),
      );
      await scanner.start();
      final startedAt = DateTime.utc(2026, 9, 3, 8);
      _scan(scanner, '4800123456', startedAt);
      scanner.acceptKey(
        'Enter',
        occurredAt: startedAt.add(const Duration(milliseconds: 55)),
      );
      _scan(
        scanner,
        '4800123456',
        startedAt.add(const Duration(milliseconds: 100)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(scans, ['4800123456']);
      await subscription.cancel();
      await scanner.dispose();
    });
  });

  group('offline receipt hardware', () {
    late AppDatabase database;
    late DriftPosHardwareRepository repository;
    late _SequenceIdGenerator ids;
    final now = DateTime.utc(2026, 9, 3, 8);

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(database, now);
      ids = _SequenceIdGenerator();
      repository = DriftPosHardwareRepository(
        database: database,
        localMutationTransaction: LocalMutationTransaction(database),
        idGenerator: ids,
        clock: FixedAppClock(now),
      );
    });

    tearDown(() => database.close());

    test(
      'printer failure queues retry and leaves completed sale intact',
      () async {
        final queued = await repository.enqueueReceipt(
          context: _context,
          request: const ReceiptPrintRequest(
            saleId: 'sale',
            registerId: 'register',
            documentText: 'Receipt MAIN-REG-0001',
            copyType: ReceiptCopyType.original,
          ),
        );
        final processor = ReceiptPrintQueueProcessor(
          repository: repository,
          printer: const _FailingPrinter(),
          clock: FixedAppClock(now),
        );

        final attempts = await processor.processDue();

        expect(queued.isSuccess, isTrue);
        expect(attempts.single.queuedForRetry, isTrue);
        expect(await database.select(database.sales).get(), hasLength(1));
        final job = await database
            .select(database.receiptPrintJobs)
            .getSingle();
        expect(
          job.status,
          ReceiptPrintJobStatus.retryableFailure.databaseValue,
        );
        expect(job.attemptCount, 1);
        expect(job.nextAttemptAt, isNotNull);
      },
    );

    test(
      'reprint is marked and persisted with audit and outbox evidence',
      () async {
        final sale = _sale();
        final document = const PlainTextReceiptRenderer().render(
          sale,
          isReprint: true,
        );
        final result = await repository.enqueueReceipt(
          context: _context,
          request: ReceiptPrintRequest(
            saleId: sale.id,
            registerId: sale.registerId,
            documentText: document.plainText,
            copyType: ReceiptCopyType.reprint,
          ),
        );

        expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
        expect(document.plainText, contains('REPRINT - NOT ORIGINAL'));
        final audit = await database
            .select(database.localAuditLogs)
            .getSingle();
        final outbox = await database
            .select(database.syncOutboxEntries)
            .getSingle();
        expect(audit.auditedEntityName, 'sale_receipt_reprint');
        expect(audit.entityId, 'sale');
        expect(outbox.commandType, 'receipt.reprint');
        expect(outbox.operationId, audit.operationId);
      },
    );

    test(
      'hardware absence returns screen and PDF fallback without a print job',
      () async {
        await (database.update(database.registers)
              ..where((row) => row.id.equals('register')))
            .write(const RegistersCompanion(printerType: Value('screen')));
        final useCase = DeliverSaleReceiptUseCase(
          repository: repository,
          processor: ReceiptPrintQueueProcessor(
            repository: repository,
            printer: const _FailingPrinter(),
            clock: FixedAppClock(now),
          ),
          renderer: const PlainTextReceiptRenderer(),
          requirePermission: const RequirePermissionUseCase(),
        );

        final result = await useCase(
          session: _session({AppPermission.processSales}),
          sale: _sale(),
          isReprint: false,
        );
        final pdf = ReceiptPdfGenerator.generate(
          const PlainTextReceiptRenderer().render(_sale()).plainText,
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.screenReceiptAvailable, isTrue);
        expect(await database.select(database.receiptPrintJobs).get(), isEmpty);
        expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      },
    );

    test(
      'cash drawer opens only for an authorized completed cash sale',
      () async {
        final drawer = _RecordingCashDrawer();
        final useCase = OpenSaleCashDrawerUseCase(
          repository: repository,
          cashDrawer: drawer,
          requirePermission: const RequirePermissionUseCase(),
        );

        final denied = await useCase(
          session: _session({AppPermission.viewDashboard}),
          sale: _sale(),
        );
        final opened = await useCase(
          session: _session({AppPermission.processSales}),
          sale: _sale(),
        );

        expect(denied.failureOrNull, isA<AuthorizationFailure>());
        expect(opened.valueOrNull, isTrue);
        expect(drawer.openCount, 1);
      },
    );
  });
}

void _scan(
  KeyboardWedgeBarcodeScanner scanner,
  String value,
  DateTime startedAt,
) {
  for (var index = 0; index < value.length; index++) {
    scanner.acceptKey(
      value[index],
      occurredAt: startedAt.add(Duration(milliseconds: index * 5)),
    );
  }
  scanner.acceptKey(
    'Enter',
    occurredAt: startedAt.add(Duration(milliseconds: value.length * 5)),
  );
}

const _context = BusinessContext(
  organizationId: 'organization',
  branchId: 'branch',
  actorUserId: 'cashier-user',
);

Future<void> _seed(AppDatabase database, DateTime now) async {
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
          name: 'Main',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.registers)
      .insert(
        RegistersCompanion.insert(
          id: 'register',
          organizationId: 'organization',
          branchId: 'branch',
          code: 'REG',
          name: 'Register',
          printerType: const Value('network_esc_pos'),
          printerAddress: const Value('192.0.2.1'),
          cashDrawerEnabled: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.sales)
      .insert(
        SalesCompanion.insert(
          id: 'sale',
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register',
          operationId: 'sale-operation',
          status: const Value('completed'),
          cashierUserId: 'cashier-user',
          completedAt: Value(now),
          createdAt: now,
          updatedAt: now,
          receiptNumber: const Value('MAIN-REG-0001'),
          subtotalMinor: const Value(10000),
          totalMinor: const Value(10000),
          tenderedMinor: const Value(10000),
        ),
      );
}

SaleRecord _sale() => SaleRecord(
  id: 'sale',
  branchId: 'branch',
  registerId: 'register',
  registerName: 'Register',
  receiptNumber: 'MAIN-REG-0001',
  status: SaleStatus.completed,
  cashierUserId: 'cashier-user',
  subtotalMinor: 10000,
  discountMinor: 0,
  taxMinor: 0,
  totalMinor: 10000,
  tenderedMinor: 10000,
  changeMinor: 0,
  completedAt: DateTime.utc(2026, 9, 3, 8),
  items: const [],
  payments: const [
    SalePayment(
      id: 'payment',
      method: SalePaymentMethod.cash,
      tenderedAmountMinor: 10000,
      appliedAmountMinor: 10000,
      changeAmountMinor: 0,
    ),
  ],
);

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
              branch: const domain_branch.Branch(
                id: 'branch',
                organizationId: 'organization',
                code: 'MAIN',
                name: 'Main',
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
  String newId() => 'hardware-id-${_value++}';
}

class _FailingPrinter implements ReceiptPrinter {
  const _FailingPrinter();

  @override
  Future<Result<void, Failure>> print({
    required String documentText,
    required RegisterHardwareProfile profile,
  }) async {
    return const Result.failure(
      NetworkFailure('Printer offline', code: 'printer-unavailable'),
    );
  }
}

class _RecordingCashDrawer implements CashDrawer {
  int openCount = 0;

  @override
  Future<Result<void, Failure>> open({
    required RegisterHardwareProfile profile,
  }) async {
    openCount++;
    return const Result.success(null);
  }
}
