import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'registers_branch_idx',
  columns: {#organizationId, #branchId, #isActive},
)
class Registers extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get assignedDeviceId => text().nullable()();
  TextColumn get assignedByUserId => text().nullable()();
  DateTimeColumn get assignedAt => dateTime().nullable()();
  TextColumn get scannerType => text()
      .withDefault(const Constant<String>('keyboard_wedge'))
      .check(
        const CustomExpression<bool>(
          "scanner_type IN ('disabled', 'keyboard_wedge', 'camera')",
        ),
      )();
  IntColumn get scannerInterCharacterTimeoutMs => integer()
      .withDefault(const Constant<int>(80))
      .check(
        const CustomExpression<bool>(
          'scanner_inter_character_timeout_ms BETWEEN 20 AND 1000',
        ),
      )();
  IntColumn get scannerDuplicateSuppressionMs => integer()
      .withDefault(const Constant<int>(350))
      .check(
        const CustomExpression<bool>(
          'scanner_duplicate_suppression_ms BETWEEN 0 AND 5000',
        ),
      )();
  TextColumn get printerType => text()
      .withDefault(const Constant<String>('screen'))
      .check(
        const CustomExpression<bool>(
          "printer_type IN ('screen', 'network_esc_pos')",
        ),
      )();
  TextColumn get printerAddress => text().nullable()();
  IntColumn get printerPort => integer()
      .withDefault(const Constant<int>(9100))
      .check(
        const CustomExpression<bool>('printer_port BETWEEN 1 AND 65535'),
      )();
  IntColumn get printerPaperWidthMm => integer()
      .withDefault(const Constant<int>(80))
      .check(
        const CustomExpression<bool>('printer_paper_width_mm IN (58, 80)'),
      )();
  BoolColumn get cashDrawerEnabled =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get cashDrawerPin => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('cash_drawer_pin IN (0, 1)'))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, branchId, code},
    {organizationId, branchId, assignedDeviceId},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    "CHECK (printer_type != 'network_esc_pos' OR "
        '(printer_address IS NOT NULL AND length(trim(printer_address)) > 0))',
  ];
}
