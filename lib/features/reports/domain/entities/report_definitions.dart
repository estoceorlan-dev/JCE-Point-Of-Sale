import 'report_dataset.dart';
import 'report_filter.dart';

class ReportDefinition {
  const ReportDefinition({
    required this.title,
    required this.formula,
    required this.columns,
  });

  final String title;
  final String formula;
  final List<ReportColumn> columns;
}

abstract final class ReportDefinitions {
  static ReportDefinition forType(ReportType type) => switch (type) {
    ReportType.dailyBranchSales => const ReportDefinition(
      title: 'Daily branch sales',
      formula:
          'Net sales = completed sale totals minus completed return totals. '
          'Voided and sync-rejected sales are excluded.',
      columns: [
        ReportColumn(
          key: 'businessDate',
          label: 'Business day',
          format: ReportValueFormat.date,
        ),
        ReportColumn(key: 'branch', label: 'Branch'),
        ReportColumn(
          key: 'transactions',
          label: 'Transactions',
          format: ReportValueFormat.integer,
        ),
        ReportColumn(
          key: 'grossSalesMinor',
          label: 'Gross sales',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'returnsMinor',
          label: 'Returns',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'netSalesMinor',
          label: 'Net sales',
          format: ReportValueFormat.moneyMinor,
        ),
      ],
    ),
    ReportType.paymentMethodTotals => const ReportDefinition(
      title: 'Payment-method totals',
      formula:
          'Net payment = applied sale payments minus completed return refunds '
          'for the same method. Cash change is not revenue.',
      columns: [
        ReportColumn(key: 'paymentMethod', label: 'Method'),
        ReportColumn(
          key: 'paymentsMinor',
          label: 'Payments',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'refundsMinor',
          label: 'Refunds',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'netMinor',
          label: 'Net',
          format: ReportValueFormat.moneyMinor,
        ),
      ],
    ),
    ReportType.cashierPerformance => const ReportDefinition(
      title: 'Cashier performance',
      formula:
          'Cashier net sales are original completed sale totals less returns '
          'against those sales. Average ticket uses completed sale count.',
      columns: [
        ReportColumn(key: 'cashier', label: 'Cashier'),
        ReportColumn(
          key: 'transactions',
          label: 'Transactions',
          format: ReportValueFormat.integer,
        ),
        ReportColumn(
          key: 'grossSalesMinor',
          label: 'Gross sales',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'returnsMinor',
          label: 'Returns',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'netSalesMinor',
          label: 'Net sales',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'averageTicketMinor',
          label: 'Average ticket',
          format: ReportValueFormat.moneyMinor,
        ),
      ],
    ),
    ReportType.productSales => const ReportDefinition(
      title: 'Product sales',
      formula:
          'Net quantity and revenue equal completed sale-item quantities and '
          'totals less completed returned items. Voids are excluded.',
      columns: [
        ReportColumn(key: 'sku', label: 'SKU'),
        ReportColumn(key: 'product', label: 'Product'),
        ReportColumn(
          key: 'soldQuantityMilli',
          label: 'Sold',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'returnedQuantityMilli',
          label: 'Returned',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'netQuantityMilli',
          label: 'Net qty',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'netRevenueMinor',
          label: 'Net revenue',
          format: ReportValueFormat.moneyMinor,
        ),
      ],
    ),
    ReportType.grossProfitEstimate => const ReportDefinition(
      title: 'Gross profit estimate',
      formula:
          'Estimated gross profit = net sale-item revenue minus snapshotted '
          'unit cost for net quantity. It is an estimate, not accounting profit.',
      columns: [
        ReportColumn(key: 'sku', label: 'SKU'),
        ReportColumn(key: 'product', label: 'Product'),
        ReportColumn(
          key: 'netRevenueMinor',
          label: 'Net revenue',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'estimatedCostMinor',
          label: 'Estimated COGS',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'grossProfitMinor',
          label: 'Gross profit',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'marginBasisPoints',
          label: 'Margin',
          format: ReportValueFormat.percentageBasisPoints,
        ),
      ],
    ),
    ReportType.inventoryValuation => const ReportDefinition(
      title: 'Inventory valuation',
      formula:
          'Value = on-hand quantity in thousandths multiplied by current '
          'weighted-average unit cost, rounded to the nearest minor unit.',
      columns: [
        ReportColumn(key: 'sku', label: 'SKU'),
        ReportColumn(key: 'product', label: 'Product'),
        ReportColumn(
          key: 'onHandMilli',
          label: 'On hand',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'averageCostMinor',
          label: 'Average cost',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'valuationMinor',
          label: 'Value',
          format: ReportValueFormat.moneyMinor,
        ),
      ],
    ),
    ReportType.lowStock => const ReportDefinition(
      title: 'Low stock',
      formula:
          'Low stock means available quantity (on hand less reserved) is at '
          'or below the location reorder point.',
      columns: [
        ReportColumn(key: 'sku', label: 'SKU'),
        ReportColumn(key: 'product', label: 'Product'),
        ReportColumn(key: 'location', label: 'Location'),
        ReportColumn(
          key: 'onHandMilli',
          label: 'On hand',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'reservedMilli',
          label: 'Reserved',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'availableMilli',
          label: 'Available',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'reorderPointMilli',
          label: 'Reorder point',
          format: ReportValueFormat.quantityMilli,
        ),
      ],
    ),
    ReportType.inventoryMovement => const ReportDefinition(
      title: 'Inventory movement',
      formula:
          'Each row is an immutable ledger entry. Reversals remain visible '
          'and balances are never reconstructed from report totals.',
      columns: [
        ReportColumn(
          key: 'occurredAt',
          label: 'Occurred',
          format: ReportValueFormat.dateTime,
        ),
        ReportColumn(key: 'type', label: 'Type'),
        ReportColumn(key: 'sku', label: 'SKU'),
        ReportColumn(key: 'product', label: 'Product'),
        ReportColumn(key: 'location', label: 'Location'),
        ReportColumn(
          key: 'quantityDeltaMilli',
          label: 'Change',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'balanceAfterMilli',
          label: 'Balance after',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(key: 'actor', label: 'Actor'),
      ],
    ),
    ReportType.shiftReconciliation => const ReportDefinition(
      title: 'Shift reconciliation',
      formula:
          'Discrepancy = counted cash minus expected cash at close. Open shifts '
          'show no closing values.',
      columns: [
        ReportColumn(
          key: 'openedAt',
          label: 'Opened',
          format: ReportValueFormat.dateTime,
        ),
        ReportColumn(key: 'register', label: 'Register'),
        ReportColumn(key: 'cashier', label: 'Cashier'),
        ReportColumn(key: 'status', label: 'Status'),
        ReportColumn(
          key: 'expectedCashMinor',
          label: 'Expected',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'countedCashMinor',
          label: 'Counted',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'discrepancyMinor',
          label: 'Difference',
          format: ReportValueFormat.moneyMinor,
        ),
      ],
    ),
    ReportType.transferPerformance => const ReportDefinition(
      title: 'Transfer performance',
      formula:
          'Quantities sum transfer lines. Lead time is elapsed minutes from '
          'shipment to receipt for received transfers.',
      columns: [
        ReportColumn(key: 'transferNumber', label: 'Transfer'),
        ReportColumn(key: 'source', label: 'Source'),
        ReportColumn(key: 'destination', label: 'Destination'),
        ReportColumn(key: 'status', label: 'Status'),
        ReportColumn(
          key: 'requestedMilli',
          label: 'Requested',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'shippedMilli',
          label: 'Shipped',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'receivedMilli',
          label: 'Received',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'damagedMilli',
          label: 'Damaged',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'leadMinutes',
          label: 'Lead time',
          format: ReportValueFormat.durationMinutes,
        ),
      ],
    ),
    ReportType.purchaseReceivingPerformance => const ReportDefinition(
      title: 'Purchase and receiving performance',
      formula:
          'Ordered value uses PO unit cost. Received cost uses goods-receipt '
          'landed unit cost. Remaining excludes cancelled quantities.',
      columns: [
        ReportColumn(key: 'orderNumber', label: 'Purchase order'),
        ReportColumn(key: 'supplier', label: 'Supplier'),
        ReportColumn(key: 'status', label: 'Status'),
        ReportColumn(
          key: 'orderedMilli',
          label: 'Ordered',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'receivedMilli',
          label: 'Received',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'remainingMilli',
          label: 'Remaining',
          format: ReportValueFormat.quantityMilli,
        ),
        ReportColumn(
          key: 'orderedValueMinor',
          label: 'Ordered value',
          format: ReportValueFormat.moneyMinor,
        ),
        ReportColumn(
          key: 'receivedCostMinor',
          label: 'Received landed cost',
          format: ReportValueFormat.moneyMinor,
        ),
      ],
    ),
  };
}
