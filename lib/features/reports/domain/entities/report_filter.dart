enum ReportType {
  dailyBranchSales,
  paymentMethodTotals,
  cashierPerformance,
  productSales,
  grossProfitEstimate,
  inventoryValuation,
  lowStock,
  inventoryMovement,
  shiftReconciliation,
  transferPerformance,
  purchaseReceivingPerformance,
}

extension ReportTypeLabel on ReportType {
  String get label => switch (this) {
    ReportType.dailyBranchSales => 'Daily branch sales',
    ReportType.paymentMethodTotals => 'Payment-method totals',
    ReportType.cashierPerformance => 'Cashier performance',
    ReportType.productSales => 'Product sales',
    ReportType.grossProfitEstimate => 'Gross profit estimate',
    ReportType.inventoryValuation => 'Inventory valuation',
    ReportType.lowStock => 'Low stock',
    ReportType.inventoryMovement => 'Inventory movement',
    ReportType.shiftReconciliation => 'Shift reconciliation',
    ReportType.transferPerformance => 'Transfer performance',
    ReportType.purchaseReceivingPerformance =>
      'Purchase and receiving performance',
  };
}

class ReportFilter {
  const ReportFilter({
    required this.branchId,
    required this.fromUtc,
    required this.toUtcExclusive,
    this.productId,
    this.categoryId,
    this.userId,
    this.paymentMethod,
    this.page = 1,
    this.pageSize = 25,
  });

  final String branchId;
  final DateTime fromUtc;
  final DateTime toUtcExclusive;
  final String? productId;
  final String? categoryId;
  final String? userId;
  final String? paymentMethod;
  final int page;
  final int pageSize;

  int get offset => (page - 1) * pageSize;
}

class ReportRequest {
  const ReportRequest({required this.type, required this.filter});

  final ReportType type;
  final ReportFilter filter;
}
