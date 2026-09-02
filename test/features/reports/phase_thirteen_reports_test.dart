import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart'
    hide AppUser, Organization;
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/branch_business_day.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/dashboard/data/data_sources/dashboard_local_data_source.dart';
import 'package:jce_pos/features/reports/data/data_sources/reports_local_data_source.dart';
import 'package:jce_pos/features/reports/data/repositories/drift_reports_repository.dart';
import 'package:jce_pos/features/reports/data/services/csv_report_exporter.dart';
import 'package:jce_pos/features/reports/domain/entities/report_dataset.dart';
import 'package:jce_pos/features/reports/domain/entities/report_filter.dart';
import 'package:jce_pos/features/reports/domain/repositories/reports_repository.dart';
import 'package:jce_pos/features/reports/domain/use_cases/load_report_use_case.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/business_context.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  group('Phase 13 reports', () {
    late AppDatabase database;
    late ReportsRepository repository;
    late ReportFilter septemberFirst;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(database);
      final businessDay = BranchBusinessDay();
      final range = businessDay.range(
        fromDate: DateTime(2026, 9, 1),
        toDate: DateTime(2026, 9, 1),
        timezoneName: 'Asia/Manila',
      );
      septemberFirst = ReportFilter(
        branchId: 'branch',
        fromUtc: range.start,
        toUtcExclusive: range.endExclusive,
        pageSize: 25,
      );
      repository = DriftReportsRepository(
        ReportsLocalDataSource(database, businessDay),
      );
    });

    tearDown(() => database.close());

    test('business-day boundaries use the configured branch timezone', () {
      expect(septemberFirst.fromUtc, DateTime.utc(2026, 8, 31, 16));
      expect(septemberFirst.toUtcExclusive, DateTime.utc(2026, 9, 1, 16));
    });

    test('sales, returns, and voids reconcile to raw records', () async {
      final daily = await _load(
        repository,
        ReportType.dailyBranchSales,
        septemberFirst,
      );
      final row = daily.rows.single;
      expect(row['transactions'], 2);
      expect(row['grossSalesMinor'], 15000);
      expect(row['returnsMinor'], 2500);
      expect(row['netSalesMinor'], 12500);

      final payments = await _load(
        repository,
        ReportType.paymentMethodTotals,
        septemberFirst,
      );
      expect(payments.totalRows, 2);
      final card = payments.rows.singleWhere(
        (value) => value['paymentMethod'] == 'Card',
      );
      expect(card['paymentsMinor'], 10000);
      expect(card['refundsMinor'], 2500);
      expect(card['netMinor'], 7500);
      final cash = payments.rows.singleWhere(
        (value) => value['paymentMethod'] == 'Cash',
      );
      expect(cash['netMinor'], 5000);
    });

    test('product sales and gross profit use snapshots and paginate', () async {
      final paged = ReportFilter(
        branchId: septemberFirst.branchId,
        fromUtc: septemberFirst.fromUtc,
        toUtcExclusive: septemberFirst.toUtcExclusive,
        pageSize: 1,
      );
      final products = await _load(repository, ReportType.productSales, paged);
      expect(products.totalRows, 2);
      expect(products.rows, hasLength(1));

      final filtered = ReportFilter(
        branchId: septemberFirst.branchId,
        fromUtc: septemberFirst.fromUtc,
        toUtcExclusive: septemberFirst.toUtcExclusive,
        productId: 'product-one',
      );
      final profit = await _load(
        repository,
        ReportType.grossProfitEstimate,
        filtered,
      );
      final row = profit.rows.single;
      expect(row['netRevenueMinor'], 7500);
      expect(row['estimatedCostMinor'], 4500);
      expect(row['grossProfitMinor'], 3000);
      expect(row['marginBasisPoints'], 4000);
    });

    test('dashboard metrics are local, scoped, and return-aware', () async {
      final summary = await DashboardLocalDataSource(database)
          .watchSummary(
            organizationId: 'organization',
            branchId: 'branch',
            fromUtc: septemberFirst.fromUtc,
            toUtcExclusive: septemberFirst.toUtcExclusive,
          )
          .first;

      expect(summary.netSalesMinor, 12500);
      expect(summary.completedSales, 2);
      expect(summary.openCarts, 1);
      expect(summary.lowStockItems, 1);
      expect(summary.grossProfitMinor, 6000);
    });

    test('report use case rejects an unassigned branch', () async {
      final filter = ReportFilter(
        branchId: 'other-branch',
        fromUtc: septemberFirst.fromUtc,
        toUtcExclusive: septemberFirst.toUtcExclusive,
      );
      final result = await LoadReportUseCase(repository).call(
        session: _session,
        type: ReportType.dailyBranchSales,
        filter: filter,
      );

      expect(result.failureOrNull, isA<AuthorizationFailure>());
    });

    test('CSV export contains exactly the filtered visible rows', () async {
      final filter = ReportFilter(
        branchId: septemberFirst.branchId,
        fromUtc: septemberFirst.fromUtc,
        toUtcExclusive: septemberFirst.toUtcExclusive,
        paymentMethod: 'card',
      );
      final dataset = await _load(
        repository,
        ReportType.paymentMethodTotals,
        filter,
      );
      final csv = const CsvReportExporter().export(
        dataset: dataset,
        filter: filter,
      );

      expect(dataset.rows, hasLength(1));
      expect(csv, contains('"Card","10000","2500","7500"'));
      expect(csv, isNot(contains('Cash')));
    });

    test(
      'every reporting model executes against the offline database',
      () async {
        for (final type in ReportType.values) {
          final result = await repository.loadReport(
            context: const BusinessContext(
              organizationId: 'organization',
              branchId: 'branch',
              actorUserId: 'user',
            ),
            type: type,
            filter: septemberFirst,
          );
          expect(
            result.isSuccess,
            isTrue,
            reason: '$type: ${result.failureOrNull}',
          );
        }
      },
    );
  });
}

Future<ReportDataset> _load(
  ReportsRepository repository,
  ReportType type,
  ReportFilter filter,
) async {
  final result = await repository.loadReport(
    context: const BusinessContext(
      organizationId: 'organization',
      branchId: 'branch',
      actorUserId: 'user',
    ),
    type: type,
    filter: filter,
  );
  expect(result.isSuccess, isTrue, reason: result.failureOrNull?.toString());
  return result.valueOrNull!;
}

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.utc(2026, 8, 1);
  await database
      .into(database.organizations)
      .insert(
        OrganizationsCompanion.insert(
          id: 'organization',
          code: 'ORG',
          name: 'Organization',
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final branch in const [('branch', 'Main'), ('other-branch', 'Other')]) {
    await database
        .into(database.branches)
        .insert(
          BranchesCompanion.insert(
            id: branch.$1,
            organizationId: 'organization',
            code: branch.$1,
            name: branch.$2,
            timezone: const Value('Asia/Manila'),
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
          email: 'cashier@example.com',
          displayName: 'Cashier One',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.units)
      .insert(
        UnitsCompanion.insert(
          id: 'unit',
          organizationId: 'organization',
          code: 'EA',
          name: 'Each',
          abbreviation: 'ea',
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final product in const [
    ('product-one', 'SKU-1', 'Product One'),
    ('product-two', 'SKU-2', 'Product Two'),
  ]) {
    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            id: product.$1,
            organizationId: 'organization',
            unitId: 'unit',
            sku: product.$2,
            normalizedSku: product.$2.replaceAll('-', ''),
            name: product.$3,
            normalizedName: product.$3.replaceAll(' ', '').toUpperCase(),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
  await database
      .into(database.stockLocations)
      .insert(
        StockLocationsCompanion.insert(
          id: 'location',
          organizationId: 'organization',
          branchId: 'branch',
          code: 'MAIN',
          name: 'Main floor',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.inventoryBalances)
      .insert(
        InventoryBalancesCompanion.insert(
          id: 'balance',
          organizationId: 'organization',
          branchId: 'branch',
          stockLocationId: 'location',
          productId: 'product-one',
          onHandMilli: const Value(1000),
          reservedMilli: const Value(200),
          reorderPointMilli: const Value(800),
          weightedAverageCostMinor: const Value(6000),
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
          createdAt: now,
          updatedAt: now,
        ),
      );
  await _insertSale(
    database,
    id: 'sale-one',
    status: 'partially_returned',
    completedAt: DateTime.utc(2026, 8, 31, 16, 30),
    totalMinor: 10000,
    productId: 'product-one',
    sku: 'SKU-1',
    productName: 'Product One',
    costMinor: 6000,
    paymentMethod: 'card',
  );
  await _insertSale(
    database,
    id: 'sale-two',
    status: 'completed',
    completedAt: DateTime.utc(2026, 9, 1, 1),
    totalMinor: 5000,
    productId: 'product-two',
    sku: 'SKU-2',
    productName: 'Product Two',
    costMinor: 2000,
    paymentMethod: 'cash',
  );
  await _insertSale(
    database,
    id: 'voided-sale',
    status: 'voided',
    completedAt: DateTime.utc(2026, 9, 1, 2),
    totalMinor: 20000,
    productId: 'product-one',
    sku: 'SKU-1',
    productName: 'Product One',
    costMinor: 6000,
    paymentMethod: 'e_wallet',
  );
  await _insertSale(
    database,
    id: 'previous-day-sale',
    status: 'completed',
    completedAt: DateTime.utc(2026, 8, 31, 15, 30),
    totalMinor: 99000,
    productId: 'product-one',
    sku: 'SKU-1',
    productName: 'Product One',
    costMinor: 6000,
    paymentMethod: 'cash',
  );
  await database
      .into(database.sales)
      .insert(
        SalesCompanion.insert(
          id: 'draft-sale',
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register',
          operationId: 'draft-operation',
          cashierUserId: 'user',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await _insertCorrection(
    database,
    id: 'return-one',
    saleId: 'sale-one',
    correctionType: 'return',
    totalMinor: 2500,
    completedAt: DateTime.utc(2026, 8, 31, 18),
    itemId: 'sale-one-item',
    quantityMilli: 250,
    refundMethod: 'card',
  );
  await _insertCorrection(
    database,
    id: 'void-one',
    saleId: 'voided-sale',
    correctionType: 'void',
    totalMinor: 20000,
    completedAt: DateTime.utc(2026, 9, 1, 2, 1),
    itemId: 'voided-sale-item',
    quantityMilli: 1000,
    refundMethod: 'e_wallet',
  );
}

Future<void> _insertSale(
  AppDatabase database, {
  required String id,
  required String status,
  required DateTime completedAt,
  required int totalMinor,
  required String productId,
  required String sku,
  required String productName,
  required int costMinor,
  required String paymentMethod,
}) async {
  await database
      .into(database.sales)
      .insert(
        SalesCompanion.insert(
          id: id,
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register',
          operationId: '$id-operation',
          status: Value(status),
          cashierUserId: 'user',
          subtotalMinor: Value(totalMinor),
          totalMinor: Value(totalMinor),
          tenderedMinor: Value(totalMinor),
          completedAt: Value(completedAt),
          createdAt: completedAt,
          updatedAt: completedAt,
        ),
      );
  await database
      .into(database.saleItems)
      .insert(
        SaleItemsCompanion.insert(
          id: '$id-item',
          organizationId: 'organization',
          branchId: 'branch',
          saleId: id,
          productId: productId,
          stockLocationId: 'location',
          lineNumber: 1,
          productNameSnapshot: productName,
          skuSnapshot: sku,
          unitNameSnapshot: 'Each',
          quantityMilli: 1000,
          unitPriceMinorSnapshot: totalMinor,
          unitCostMinorSnapshot: costMinor,
          taxRateBasisPointsSnapshot: 0,
          taxInclusiveSnapshot: false,
          grossAmountMinor: totalMinor,
          discountAmountMinor: 0,
          netAmountMinor: totalMinor,
          taxAmountMinor: 0,
          totalAmountMinor: totalMinor,
          createdAt: completedAt,
        ),
      );
  await database
      .into(database.payments)
      .insert(
        PaymentsCompanion.insert(
          id: '$id-payment',
          organizationId: 'organization',
          branchId: 'branch',
          saleId: id,
          paymentMethod: paymentMethod,
          tenderedAmountMinor: totalMinor,
          appliedAmountMinor: totalMinor,
          createdAt: completedAt,
        ),
      );
}

Future<void> _insertCorrection(
  AppDatabase database, {
  required String id,
  required String saleId,
  required String correctionType,
  required int totalMinor,
  required DateTime completedAt,
  required String itemId,
  required int quantityMilli,
  required String refundMethod,
}) async {
  await database
      .into(database.saleReturns)
      .insert(
        SaleReturnsCompanion.insert(
          id: id,
          organizationId: 'organization',
          branchId: 'branch',
          saleId: saleId,
          operationId: '$id-operation',
          returnNumber: id,
          correctionType: correctionType,
          reasonCode: 'TEST',
          subtotalMinor: totalMinor,
          discountMinor: 0,
          taxMinor: 0,
          totalMinor: totalMinor,
          createdByUserId: 'user',
          completedAt: completedAt,
          createdAt: completedAt,
          updatedAt: completedAt,
        ),
      );
  await database
      .into(database.saleReturnItems)
      .insert(
        SaleReturnItemsCompanion.insert(
          id: '$id-item',
          organizationId: 'organization',
          branchId: 'branch',
          saleReturnId: id,
          saleItemId: itemId,
          productId: 'product-one',
          disposition: 'non_restock',
          quantityMilli: quantityMilli,
          subtotalMinor: totalMinor,
          discountMinor: 0,
          taxMinor: 0,
          totalMinor: totalMinor,
          createdAt: completedAt,
        ),
      );
  await database
      .into(database.refundPayments)
      .insert(
        RefundPaymentsCompanion.insert(
          id: '$id-refund',
          organizationId: 'organization',
          branchId: 'branch',
          saleReturnId: id,
          refundMethod: refundMethod,
          amountMinor: totalMinor,
          createdAt: completedAt,
        ),
      );
}

final _session = AuthSession(
  user: AppUser(
    firebaseUid: 'firebase-user',
    email: 'user@example.com',
    displayName: 'User',
    organizations: [
      OrganizationAccess(
        appUserId: 'user',
        organization: const Organization(
          id: 'organization',
          code: 'ORG',
          name: 'Organization',
          timezone: 'Asia/Manila',
        ),
        status: UserAccountStatus.active,
        organizationRoles: const [],
        branches: [
          BranchAccess(
            branch: const Branch(
              id: 'branch',
              organizationId: 'organization',
              code: 'MAIN',
              name: 'Main',
              timezone: 'Asia/Manila',
            ),
            roles: const [
              AccessRole(
                id: 'reporter',
                code: 'reporter',
                name: 'Reporter',
                permissions: {AppPermission.viewReports},
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  activeOrganizationId: 'organization',
  activeBranchId: 'branch',
);
