enum InventoryTransactionType {
  openingBalance('opening_balance', 'Opening balance'),
  purchaseReceipt('purchase_receipt', 'Purchase receipt'),
  sale('sale', 'Sale'),
  saleReturn('sale_return', 'Sale return'),
  adjustmentIncrease('adjustment_increase', 'Adjustment increase'),
  adjustmentDecrease('adjustment_decrease', 'Adjustment decrease'),
  transferShipment('transfer_shipment', 'Transfer shipment'),
  transferReceipt('transfer_receipt', 'Transfer receipt'),
  stockCountCorrection('stock_count_correction', 'Stock count correction'),
  reversal('reversal', 'Reversal');

  const InventoryTransactionType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static InventoryTransactionType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () =>
          throw FormatException('Unknown inventory transaction type: $value'),
    );
  }
}
