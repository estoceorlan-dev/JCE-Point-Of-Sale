enum AppPermission {
  viewDashboard('dashboard.view'),
  processSales('sales.process'),
  approveSaleDiscounts('sales.discounts.approve'),
  processSaleReturns('sales.returns.process'),
  approveSaleCorrections('sales.corrections.approve'),
  manageProducts('products.manage'),
  manageInventory('inventory.manage'),
  approveInventoryAdjustments('inventory.adjustments.approve'),
  manageRegisters('registers.manage'),
  approveShiftDiscrepancies('shifts.discrepancies.approve'),
  approveTransfers('transfers.approve'),
  createPurchases('purchases.create'),
  approvePurchases('purchases.approve'),
  receivePurchases('purchases.receive'),
  manageSuppliers('suppliers.manage'),
  viewCustomers('customers.view'),
  manageCustomers('customers.manage'),
  anonymizeCustomers('customers.anonymize'),
  manageLoyalty('loyalty.manage'),
  manageBranches('branches.manage'),
  viewReports('reports.view'),
  viewAuditLogs('audit_logs.view'),
  manageUsers('users.manage'),
  manageRoles('roles.manage'),
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
