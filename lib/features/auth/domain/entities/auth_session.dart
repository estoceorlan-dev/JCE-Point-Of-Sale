import '../../../../shared/models/access_role.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/branch_access.dart';
import '../../../../shared/models/organization_access.dart';
import '../../../../shared/models/permission.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.activeOrganizationId,
    required this.activeBranchId,
  });

  final AppUser user;
  final String activeOrganizationId;
  final String activeBranchId;

  OrganizationAccess get activeOrganization {
    final organization = user.organizationById(activeOrganizationId);
    if (organization == null) {
      throw StateError('The active organization is not assigned to the user.');
    }
    return organization;
  }

  BranchAccess get activeBranch {
    final branch = activeOrganization.branchById(activeBranchId);
    if (branch == null) {
      throw StateError('The active branch is not assigned to the user.');
    }
    return branch;
  }

  Set<AppPermission> get permissions =>
      activeOrganization.permissionsFor(activeBranchId);

  List<AccessRole> get roles => activeOrganization.rolesFor(activeBranchId);

  bool can(AppPermission permission) => permissions.contains(permission);

  bool canOrganizationWide(AppPermission permission) => activeOrganization
      .organizationRoles
      .any((role) => role.permissions.contains(permission));

  Set<AppPermission> get administrationPermissions => {
    for (final permission in const [
      AppPermission.manageBranches,
      AppPermission.manageUsers,
      AppPermission.manageRoles,
      AppPermission.manageRegisters,
      AppPermission.manageProducts,
    ])
      if (canOrganizationWide(permission)) permission,
  };

  String get administrationScopeKey =>
      (administrationPermissions.map((value) => value.code).toList()..sort())
          .join(',');

  AuthSession switchTo({
    required String organizationId,
    required String branchId,
  }) {
    final organization = user.organizationById(organizationId);
    if (organization == null ||
        !organization.canSignIn ||
        organization.branchById(branchId) == null) {
      throw ArgumentError('The selected branch is not assigned to this user.');
    }
    return AuthSession(
      user: user,
      activeOrganizationId: organizationId,
      activeBranchId: branchId,
    );
  }
}
