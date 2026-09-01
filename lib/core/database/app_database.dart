// ignore_for_file: experimental_member_use

import 'package:drift/drift.dart';

import 'app_database_config.dart';
import 'daos/audit_log_dao.dart';
import 'daos/metadata_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/sync_conflict_dao.dart';
import 'daos/sync_cursor_dao.dart';
import 'daos/sync_entity_version_dao.dart';
import 'database_connection.dart';
import 'models/outbox_state.dart';
import 'tables/app_users_table.dart';
import 'tables/approval_decisions_table.dart';
import 'tables/approval_requests_table.dart';
import 'tables/branches_table.dart';
import 'tables/cash_movements_table.dart';
import 'tables/categories_table.dart';
import 'tables/goods_receipt_items_table.dart';
import 'tables/goods_receipts_table.dart';
import 'tables/inventory_balances_table.dart';
import 'tables/inventory_ledger_entries_table.dart';
import 'tables/inventory_transactions_table.dart';
import 'tables/local_audit_logs_table.dart';
import 'tables/local_metadata_table.dart';
import 'tables/organizations_table.dart';
import 'tables/permissions_table.dart';
import 'tables/product_barcodes_table.dart';
import 'tables/product_images_table.dart';
import 'tables/product_prices_table.dart';
import 'tables/products_table.dart';
import 'tables/purchase_order_items_table.dart';
import 'tables/purchase_orders_table.dart';
import 'tables/payments_table.dart';
import 'tables/receipt_sequences_table.dart';
import 'tables/registers_table.dart';
import 'tables/role_permissions_table.dart';
import 'tables/roles_table.dart';
import 'tables/sale_discounts_table.dart';
import 'tables/sale_items_table.dart';
import 'tables/sale_return_items_table.dart';
import 'tables/sale_returns_table.dart';
import 'tables/sales_table.dart';
import 'tables/refund_payments_table.dart';
import 'tables/sync_conflicts_table.dart';
import 'tables/sync_cursors_table.dart';
import 'tables/sync_entity_versions_table.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/stock_count_items_table.dart';
import 'tables/stock_counts_table.dart';
import 'tables/stock_locations_table.dart';
import 'tables/stock_transfer_items_table.dart';
import 'tables/stock_transfers_table.dart';
import 'tables/supplier_contacts_table.dart';
import 'tables/supplier_products_table.dart';
import 'tables/suppliers_table.dart';
import 'tables/shift_counts_table.dart';
import 'tables/shifts_table.dart';
import 'tables/tax_categories_table.dart';
import 'tables/units_table.dart';
import 'tables/user_role_assignments_table.dart';
import 'tables/transfer_events_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    LocalMetadata,
    SyncOutboxEntries,
    SyncCursors,
    SyncConflicts,
    SyncEntityVersions,
    LocalAuditLogs,
    Organizations,
    Branches,
    AppUsers,
    Roles,
    Permissions,
    RolePermissions,
    UserRoleAssignments,
    Categories,
    Units,
    TaxCategories,
    Products,
    ProductBarcodes,
    ProductPrices,
    ProductImages,
    StockLocations,
    InventoryTransactions,
    InventoryLedgerEntries,
    InventoryBalances,
    StockCounts,
    StockCountItems,
    Registers,
    Shifts,
    CashMovements,
    ShiftCounts,
    Sales,
    SaleItems,
    Payments,
    SaleDiscounts,
    ReceiptSequences,
    ApprovalRequests,
    ApprovalDecisions,
    SaleReturns,
    SaleReturnItems,
    RefundPayments,
    StockTransfers,
    StockTransferItems,
    TransferEvents,
    Suppliers,
    SupplierContacts,
    SupplierProducts,
    PurchaseOrders,
    PurchaseOrderItems,
    GoodsReceipts,
    GoodsReceiptItems,
  ],
  daos: [
    MetadataDao,
    OutboxDao,
    SyncCursorDao,
    SyncConflictDao,
    SyncEntityVersionDao,
    AuditLogDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(AppDatabaseConfig config)
    : super(config.executor ?? openDatabaseConnection(config.name));

  AppDatabase.forTesting(super.executor);

  static const int currentSchemaVersion = 10;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      await transaction(() async {
        for (var version = from + 1; version <= to; version++) {
          await _migrateTo(migrator, version);
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (!details.wasCreated) {
        await customUpdate(
          'UPDATE sync_outbox '
          'SET status = ?, next_attempt_at = NULL, '
          'last_error = COALESCE(last_error, ?) '
          'WHERE status = ?',
          variables: [
            Variable<String>(OutboxState.pending.databaseValue),
            const Variable<String>(
              'Recovered processing operation after application restart.',
            ),
            Variable<String>(OutboxState.processing.databaseValue),
          ],
          updates: {syncOutboxEntries},
        );
      }
    },
  );

  Future<void> _migrateTo(Migrator migrator, int version) async {
    switch (version) {
      case 1:
        await migrator.createAll();
      case 2:
        await migrator.createTable(categories);
        await migrator.createTable(units);
        await migrator.createTable(taxCategories);
        await migrator.createTable(products);
        await migrator.createTable(productBarcodes);
        await migrator.createTable(productPrices);
        await migrator.createTable(productImages);
        await migrator.createIndex(categoriesSearchIdx);
        await migrator.createIndex(productsNameSearchIdx);
        await migrator.createIndex(productsSkuSearchIdx);
        await migrator.createIndex(productBarcodesSearchIdx);
      case 3:
        await migrator.alterTable(
          TableMigration(
            branches,
            columnTransformer: {
              branches.allowNegativeStock: const Constant<bool>(false),
              branches.adjustmentApprovalThresholdMilli:
                  const CustomExpression<int>('NULL'),
              branches.allowMultipleOpenShiftsPerUser: const Constant<bool>(
                false,
              ),
              branches.allowSalesWithoutOpenShift: const Constant<bool>(false),
              branches.cashDiscrepancyApprovalThresholdMinor:
                  const CustomExpression<int>('NULL'),
              branches.discountApprovalThresholdBasisPoints:
                  const CustomExpression<int>('NULL'),
              branches.returnApprovalThresholdMinor:
                  const CustomExpression<int>('NULL'),
              branches.voidWindowMinutes: const Constant<int>(15),
              branches.transferApprovalThresholdMilli:
                  const CustomExpression<int>('NULL'),
            },
          ),
        );
        await migrator.alterTable(TableMigration(categories));
        await migrator.alterTable(TableMigration(units));
        await migrator.alterTable(TableMigration(taxCategories));
        await migrator.alterTable(TableMigration(products));
        await migrator.alterTable(TableMigration(productBarcodes));
        await migrator.alterTable(TableMigration(productPrices));
        await migrator.alterTable(TableMigration(productImages));
      case 4:
        if (!await _tableHasColumn('branches', 'allow_negative_stock')) {
          await migrator.addColumn(branches, branches.allowNegativeStock);
        }
        if (!await _tableHasColumn(
          'branches',
          'adjustment_approval_threshold_milli',
        )) {
          await migrator.addColumn(
            branches,
            branches.adjustmentApprovalThresholdMilli,
          );
        }
        await migrator.createTable(stockLocations);
        await migrator.createTable(inventoryTransactions);
        await migrator.createTable(inventoryLedgerEntries);
        await migrator.createTable(inventoryBalances);
        await migrator.createTable(stockCounts);
        await migrator.createTable(stockCountItems);
        await migrator.createIndex(stockLocationsBranchIdx);
        await migrator.createIndex(inventoryTransactionsHistoryIdx);
        await migrator.createIndex(inventoryLedgerProductHistoryIdx);
        await migrator.createIndex(inventoryBalancesLowStockIdx);
        await migrator.createIndex(stockCountsStatusIdx);
      case 5:
        if (!await _tableHasColumn(
          'branches',
          'allow_multiple_open_shifts_per_user',
        )) {
          await migrator.addColumn(
            branches,
            branches.allowMultipleOpenShiftsPerUser,
          );
        }
        if (!await _tableHasColumn(
          'branches',
          'allow_sales_without_open_shift',
        )) {
          await migrator.addColumn(
            branches,
            branches.allowSalesWithoutOpenShift,
          );
        }
        if (!await _tableHasColumn(
          'branches',
          'cash_discrepancy_approval_threshold_minor',
        )) {
          await migrator.addColumn(
            branches,
            branches.cashDiscrepancyApprovalThresholdMinor,
          );
        }
        await migrator.createTable(registers);
        await migrator.createTable(shifts);
        await migrator.createTable(cashMovements);
        await migrator.createTable(shiftCounts);
        await migrator.createIndex(registersBranchIdx);
        await migrator.createIndex(shiftsActiveIdx);
        await migrator.createIndex(cashMovementsShiftIdx);
      case 6:
        if (!await _tableHasColumn(
          'branches',
          'discount_approval_threshold_basis_points',
        )) {
          await migrator.addColumn(
            branches,
            branches.discountApprovalThresholdBasisPoints,
          );
        }
        await migrator.createTable(sales);
        await migrator.createTable(saleItems);
        await migrator.createTable(payments);
        await migrator.createTable(saleDiscounts);
        await migrator.createTable(receiptSequences);
        await migrator.createIndex(salesHistoryIdx);
        await migrator.createIndex(paymentsShiftIdx);
      case 7:
        if (!await _tableHasColumn('sync_outbox', 'actor_user_id')) {
          await migrator.addColumn(
            syncOutboxEntries,
            syncOutboxEntries.actorUserId,
          );
        }
        if (!await _tableHasColumn('sync_conflicts', 'organization_id')) {
          await migrator.addColumn(syncConflicts, syncConflicts.organizationId);
        }
        if (!await _tableHasColumn('sync_conflicts', 'branch_id')) {
          await migrator.addColumn(syncConflicts, syncConflicts.branchId);
        }
        if (!await _tableHasColumn('sync_conflicts', 'actor_user_id')) {
          await migrator.addColumn(syncConflicts, syncConflicts.actorUserId);
        }
        await migrator.createTable(syncEntityVersions);
        await customUpdate(
          'UPDATE sync_outbox SET actor_user_id = ('
          'SELECT actor_user_id FROM local_audit_logs audit '
          'WHERE audit.operation_id = sync_outbox.operation_id LIMIT 1) '
          'WHERE actor_user_id IS NULL',
          updates: {syncOutboxEntries},
        );
      case 8:
        if (!await _tableHasColumn('sync_outbox', 'depends_on_operation_id')) {
          await migrator.addColumn(
            syncOutboxEntries,
            syncOutboxEntries.dependsOnOperationId,
          );
        }
        if (!await _tableHasColumn(
          'branches',
          'return_approval_threshold_minor',
        )) {
          await migrator.addColumn(
            branches,
            branches.returnApprovalThresholdMinor,
          );
        }
        if (!await _tableHasColumn('branches', 'void_window_minutes')) {
          await migrator.addColumn(branches, branches.voidWindowMinutes);
        }
        await migrator.createTable(approvalRequests);
        await migrator.createTable(approvalDecisions);
        await migrator.createTable(saleReturns);
        await migrator.createTable(saleReturnItems);
        await migrator.createTable(refundPayments);
        await migrator.createIndex(approvalRequestsStatusIdx);
        await migrator.createIndex(saleReturnsHistoryIdx);
      case 9:
        if (!await _tableHasColumn(
          'branches',
          'transfer_approval_threshold_milli',
        )) {
          await migrator.addColumn(
            branches,
            branches.transferApprovalThresholdMilli,
          );
        }
        await migrator.createTable(stockTransfers);
        await migrator.createTable(stockTransferItems);
        await migrator.createTable(transferEvents);
        await migrator.createIndex(stockTransfersSourceStatusIdx);
        await migrator.createIndex(stockTransfersDestinationStatusIdx);
        await migrator.createIndex(transferEventsHistoryIdx);
      case 10:
        if (!await _tableHasColumn(
          'inventory_balances',
          'weighted_average_cost_minor',
        )) {
          await migrator.addColumn(
            inventoryBalances,
            inventoryBalances.weightedAverageCostMinor,
          );
        }
        await migrator.createTable(suppliers);
        await migrator.createTable(supplierContacts);
        await migrator.createTable(supplierProducts);
        await migrator.createTable(purchaseOrders);
        await migrator.createTable(purchaseOrderItems);
        await migrator.createTable(goodsReceipts);
        await migrator.createTable(goodsReceiptItems);
        await migrator.createIndex(suppliersSearchIdx);
        await migrator.createIndex(purchaseOrdersBranchStatusIdx);
        await migrator.createIndex(goodsReceiptsHistoryIdx);
      default:
        throw StateError('Missing migration for schema version $version.');
    }
  }

  Future<bool> _tableHasColumn(String tableName, String columnName) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    return columns.any((row) => row.read<String>('name') == columnName);
  }
}
