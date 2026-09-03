import 'operational_setting.dart';

enum ReasonCodeCategory {
  inventoryAdjustment('inventory_adjustment', 'Inventory adjustments'),
  stockCountVariance('stock_count_variance', 'Stock count variances'),
  saleReturn('sale_return', 'Returns and voids'),
  cashMovement('cash_movement', 'Cash movements'),
  transferDiscrepancy('transfer_discrepancy', 'Transfer discrepancies');

  const ReasonCodeCategory(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ReasonCodeCategory fromDatabase(String value) => values.firstWhere(
    (category) => category.databaseValue == value,
    orElse: () => ReasonCodeCategory.inventoryAdjustment,
  );
}

class ReasonCode {
  const ReasonCode({
    required this.id,
    required this.organizationId,
    required this.category,
    required this.code,
    required this.label,
    required this.requiresNote,
    required this.isActive,
    required this.sortOrder,
    required this.scope,
    required this.version,
    this.branchId,
  });

  final String id;
  final String organizationId;
  final String? branchId;
  final ReasonCodeCategory category;
  final String code;
  final String label;
  final bool requiresNote;
  final bool isActive;
  final int sortOrder;
  final SettingScope scope;
  final int version;
}

class ReasonCodeDraft {
  const ReasonCodeDraft({
    required this.category,
    required this.code,
    required this.label,
    required this.requiresNote,
    required this.scope,
    this.id,
    this.isActive = true,
    this.sortOrder = 0,
    this.expectedVersion,
    this.operationId,
  });

  final String? id;
  final ReasonCodeCategory category;
  final String code;
  final String label;
  final bool requiresNote;
  final bool isActive;
  final int sortOrder;
  final SettingScope scope;
  final int? expectedVersion;
  final String? operationId;
}
