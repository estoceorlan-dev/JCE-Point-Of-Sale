enum SaleStatus {
  draft('draft', 'Draft'),
  completed('completed', 'Completed'),
  voided('voided', 'Voided'),
  partiallyReturned('partially_returned', 'Partially returned'),
  returned('returned', 'Returned'),
  syncRejected('sync_rejected', 'Sync rejected');

  const SaleStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static SaleStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => SaleStatus.syncRejected,
    );
  }
}
