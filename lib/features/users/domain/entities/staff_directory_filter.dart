import '../../../../shared/models/user_account_status.dart';
import 'staff_account.dart';

/// Branch and role must match the same assignment. An organization-wide
/// assignment applies to every branch, but does not grant operational access.
class StaffDirectoryFilter {
  const StaffDirectoryFilter({
    this.search = '',
    this.status,
    this.branchId,
    this.roleId,
    this.pendingOnly = false,
  });

  final String search;
  final UserAccountStatus? status;
  final String? branchId;
  final String? roleId;
  final bool pendingOnly;

  bool matches(StaffAccount account) {
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty &&
        !account.displayName.toLowerCase().contains(needle) &&
        !account.email.toLowerCase().contains(needle)) {
      return false;
    }
    if (status != null && account.status != status) return false;
    if (pendingOnly && account.pendingOperations == 0) return false;
    return (branchId == null && roleId == null) ||
        account.assignments.any(
          (assignment) =>
              (branchId == null ||
                  assignment.branchId == null ||
                  assignment.branchId == branchId) &&
              (roleId == null || assignment.roleId == roleId),
        );
  }
}
