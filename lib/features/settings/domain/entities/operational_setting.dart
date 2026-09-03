enum SettingScope { organization, branch }

enum SettingOrigin { builtInDefault, organization, branch }

enum OperationalSettingKey {
  taxBehavior(
    'tax.behavior',
    'Tax behavior',
    'Use each product tax category, or force inclusive/exclusive display.',
    'per_product',
  ),
  inventoryAllowNegativeStock(
    'inventory.allow_negative_stock',
    'Allow negative stock',
    'Permit a branch inventory balance to fall below zero.',
    false,
  ),
  inventoryAdjustmentApprovalThresholdMilli(
    'inventory.adjustment_approval_threshold_milli',
    'Adjustment approval threshold',
    'Require approval at or above this quantity in thousandths.',
    null,
  ),
  receiptHeader(
    'receipt.header',
    'Receipt header',
    'Business name printed at the top of receipts.',
    'JCE General Merchandise',
  ),
  receiptFooter(
    'receipt.footer',
    'Receipt footer',
    'Message printed at the bottom of receipts.',
    'Thank you!',
  ),
  receiptShowTaxBreakdown(
    'receipt.show_tax_breakdown',
    'Show tax breakdown',
    'Print subtotal, discount, and tax lines.',
    true,
  ),
  receiptPaperWidth(
    'receipt.paper_width_characters',
    'Receipt paper width',
    'Plain-text receipt width in characters.',
    42,
  ),
  salesDiscountLimitBasisPoints(
    'sales.discount_limit_basis_points',
    'Maximum discount',
    'Maximum discount allowed, expressed in basis points.',
    10000,
  ),
  salesDiscountApprovalThresholdBasisPoints(
    'sales.discount_approval_threshold_basis_points',
    'Discount approval threshold',
    'Require approval at or above this discount in basis points.',
    null,
  ),
  shiftsAllowMultipleOpen(
    'shifts.allow_multiple_open_per_user',
    'Multiple open shifts',
    'Allow one user to operate more than one open shift.',
    false,
  ),
  shiftsAllowSalesWithoutOpen(
    'shifts.allow_sales_without_open_shift',
    'Sales without an open shift',
    'Permit checkout when no active shift is available.',
    false,
  ),
  shiftsCashDiscrepancyApprovalThresholdMinor(
    'shifts.cash_discrepancy_approval_threshold_minor',
    'Cash discrepancy approval threshold',
    'Require approval at or above this discrepancy in minor units.',
    null,
  ),
  returnsApprovalThresholdMinor(
    'returns.approval_threshold_minor',
    'Return approval threshold',
    'Require approval at or above this return value in minor units.',
    null,
  ),
  returnsVoidWindowMinutes(
    'returns.void_window_minutes',
    'Void window',
    'Maximum number of minutes after a sale that it can be voided.',
    15,
  ),
  transfersApprovalThresholdMilli(
    'transfers.approval_threshold_milli',
    'Transfer approval threshold',
    'Require approval at or above this transfer quantity.',
    null,
  );

  const OperationalSettingKey(
    this.key,
    this.label,
    this.description,
    this.defaultValue,
  );

  final String key;
  final String label;
  final String description;
  final Object? defaultValue;

  static OperationalSettingKey? fromKey(String key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return null;
  }

  bool get allowsNull => switch (this) {
    inventoryAdjustmentApprovalThresholdMilli ||
    salesDiscountApprovalThresholdBasisPoints ||
    shiftsCashDiscrepancyApprovalThresholdMinor ||
    returnsApprovalThresholdMinor ||
    transfersApprovalThresholdMilli => true,
    _ => false,
  };
}

class ResolvedSetting {
  const ResolvedSetting({
    required this.key,
    required this.value,
    required this.origin,
    this.version,
  });

  final OperationalSettingKey key;
  final Object? value;
  final SettingOrigin origin;
  final int? version;
}

class OperationalSettings {
  const OperationalSettings(this.values);

  factory OperationalSettings.defaults() => OperationalSettings({
    for (final key in OperationalSettingKey.values)
      key: ResolvedSetting(
        key: key,
        value: key.defaultValue,
        origin: SettingOrigin.builtInDefault,
      ),
  });

  final Map<OperationalSettingKey, ResolvedSetting> values;

  ResolvedSetting operator [](OperationalSettingKey key) => values[key]!;

  bool boolean(OperationalSettingKey key) => this[key].value as bool;
  int? integer(OperationalSettingKey key) => this[key].value as int?;
  String text(OperationalSettingKey key) => this[key].value as String;
}
