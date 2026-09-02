class DashboardSummary {
  const DashboardSummary({
    required this.netSalesMinor,
    required this.completedSales,
    required this.openCarts,
    required this.lowStockItems,
    required this.grossProfitMinor,
  });

  const DashboardSummary.empty()
    : netSalesMinor = 0,
      completedSales = 0,
      openCarts = 0,
      lowStockItems = 0,
      grossProfitMinor = 0;

  final int netSalesMinor;
  final int completedSales;
  final int openCarts;
  final int lowStockItems;
  final int grossProfitMinor;
}
