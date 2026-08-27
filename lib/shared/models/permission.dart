enum AppPermission {
  viewDashboard('dashboard.view'),
  processSales('sales.process'),
  approveSaleDiscounts('sales.discounts.approve'),
  manageProducts('products.manage'),
  manageInventory('inventory.manage'),
  approveInventoryAdjustments('inventory.adjustments.approve'),
  manageRegisters('registers.manage'),
  approveShiftDiscrepancies('shifts.discrepancies.approve'),
  approveTransfers('transfers.approve'),
  createPurchases('purchases.create'),
  viewReports('reports.view'),
  viewAuditLogs('audit_logs.view'),
  manageUsers('users.manage'),
  manageSettings('settings.manage');

  const AppPermission(this.code);

  final String code;

  static AppPermission? fromCode(String code) {
    for (final permission in values) {
      if (permission.code == code.trim()) {
        return permission;
      }
    }
    return null;
  }
}
