import 'package:drift/drift.dart';

import 'organizations_table.dart';

class Branches extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get timezone =>
      text().withDefault(const Constant<String>('Asia/Manila'))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
  BoolColumn get allowNegativeStock =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get adjustmentApprovalThresholdMilli => integer().nullable().check(
    const CustomExpression<bool>(
      'adjustment_approval_threshold_milli IS NULL OR '
      'adjustment_approval_threshold_milli >= 0',
    ),
  )();
  BoolColumn get allowMultipleOpenShiftsPerUser =>
      boolean().withDefault(const Constant<bool>(false))();
  BoolColumn get allowSalesWithoutOpenShift =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get cashDiscrepancyApprovalThresholdMinor =>
      integer().nullable().check(
        const CustomExpression<bool>(
          'cash_discrepancy_approval_threshold_minor IS NULL OR '
          'cash_discrepancy_approval_threshold_minor >= 0',
        ),
      )();
  IntColumn get discountApprovalThresholdBasisPoints =>
      integer().nullable().check(
        const CustomExpression<bool>(
          'discount_approval_threshold_basis_points IS NULL OR '
          '(discount_approval_threshold_basis_points >= 0 AND '
          'discount_approval_threshold_basis_points <= 10000)',
        ),
      )();
  IntColumn get returnApprovalThresholdMinor => integer().nullable().check(
    const CustomExpression<bool>(
      'return_approval_threshold_minor IS NULL OR '
      'return_approval_threshold_minor >= 0',
    ),
  )();
  IntColumn get voidWindowMinutes => integer()
      .withDefault(const Constant<int>(15))
      .check(const CustomExpression<bool>('void_window_minutes >= 0'))();
  IntColumn get transferApprovalThresholdMilli => integer().nullable().check(
    const CustomExpression<bool>(
      'transfer_approval_threshold_milli IS NULL OR '
      'transfer_approval_threshold_milli >= 0',
    ),
  )();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, code},
    {id, organizationId},
  ];
}
