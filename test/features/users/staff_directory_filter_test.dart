import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/users/domain/entities/staff_account.dart';
import 'package:jce_pos/features/users/domain/entities/staff_directory_filter.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  final account = StaffAccount(
    id: 'user',
    organizationId: 'org',
    email: 'Alice@example.test',
    displayName: 'Alice Cashier',
    status: UserAccountStatus.active,
    assignments: const [
      StaffAssignment(
        id: 'a',
        userId: 'user',
        roleId: 'cashier',
        roleName: 'Cashier',
        branchId: 'main',
        version: 0,
      ),
      StaffAssignment(
        id: 'b',
        userId: 'user',
        roleId: 'supervisor',
        roleName: 'Supervisor',
        branchId: 'second',
        version: 0,
      ),
      StaffAssignment(
        id: 'c',
        userId: 'user',
        roleId: 'auditor',
        roleName: 'Auditor',
        version: 0,
      ),
    ],
    version: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    pendingOperations: 2,
  );

  test('branch and role must apply together, including organization roles', () {
    expect(
      const StaffDirectoryFilter(
        branchId: 'main',
        roleId: 'cashier',
      ).matches(account),
      isTrue,
    );
    expect(
      const StaffDirectoryFilter(
        branchId: 'main',
        roleId: 'supervisor',
      ).matches(account),
      isFalse,
    );
    expect(
      const StaffDirectoryFilter(
        branchId: 'other',
        roleId: 'auditor',
      ).matches(account),
      isTrue,
    );
  });

  test(
    'search, status, and pending filters combine without altering staff',
    () {
      expect(
        const StaffDirectoryFilter(
          search: ' ALICE@EXAMPLE ',
          status: UserAccountStatus.active,
          pendingOnly: true,
        ).matches(account),
        isTrue,
      );
      expect(
        const StaffDirectoryFilter(
          status: UserAccountStatus.disabled,
        ).matches(account),
        isFalse,
      );
      expect(
        const StaffDirectoryFilter(search: 'Bob').matches(account),
        isFalse,
      );
      expect(account.assignments, hasLength(3));
    },
  );
}
