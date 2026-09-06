import 'access_role.dart';
import 'branch_access.dart';
import 'organization.dart';
import 'permission.dart';
import 'user_account_status.dart';

class OrganizationAccess {
  const OrganizationAccess({
    required this.appUserId,
    required this.organization,
    required this.status,
    required this.organizationRoles,
    required this.branches,
  });

  final String appUserId;
  final Organization organization;
  final UserAccountStatus status;
  final List<AccessRole> organizationRoles;
  final List<BranchAccess> branches;

  bool get canSignIn => status == UserAccountStatus.active;

  BranchAccess? branchById(String branchId) {
    for (final branch in branches) {
      if (branch.branch.id == branchId && branch.branch.isActive) {
        return branch;
      }
    }
    return null;
  }

  Set<AppPermission> permissionsFor(String branchId) {
    final branch = branchById(branchId);
    if (branch == null) {
      return const <AppPermission>{};
    }
    return {
      for (final role in organizationRoles) ...role.permissions,
      ...branch.permissions,
    };
  }

  List<AccessRole> rolesFor(String branchId) {
    final branchRoles = branchById(branchId)?.roles ?? const <AccessRole>[];
    final rolesById = <String, AccessRole>{
      for (final role in organizationRoles) role.id: role,
      for (final role in branchRoles) role.id: role,
    };
    return rolesById.values.toList(growable: false);
  }
}
