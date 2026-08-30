import 'package:drift/drift.dart';

import 'approval_requests_table.dart';
import 'branches_table.dart';
import 'organizations_table.dart';

class ApprovalDecisions extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get approvalRequestId =>
      text().references(ApprovalRequests, #id, onDelete: KeyAction.restrict)();
  TextColumn get decision => text()();
  TextColumn get decidedByUserId => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get decidedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {approvalRequestId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (approval_request_id, organization_id, branch_id) '
        'REFERENCES approval_requests (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    "CHECK (decision IN ('approved', 'rejected'))",
  ];
}
