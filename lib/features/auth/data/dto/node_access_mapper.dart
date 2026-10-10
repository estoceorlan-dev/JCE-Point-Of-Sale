import '../../../../shared/models/access_role.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/branch.dart';
import '../../../../shared/models/branch_access.dart';
import '../../../../shared/models/organization.dart';
import '../../../../shared/models/organization_access.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/models/user_account_status.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/offline/offline_grant.dart';

AuthSession nodeAccessSession(
  Map<String, dynamic> value, {
  String? branchId,
  OfflineGrant? offline,
}) {
  final org = value['organization'] as Map;
  final organizationId = value['organizationId'] as String;
  AccessRole effective(String scope, Iterable permissions) => AccessRole(
    id: 'effective:${value['userId']}:$scope',
    code: 'effective_${value['userId']}_$scope',
    name: 'Authorized access',
    permissions: permissions
        .map((p) => AppPermission.fromCode(p as String))
        .whereType<AppPermission>()
        .toSet(),
  );
  final branches = (value['branches'] as List)
      .cast<Map>()
      .where((b) => offline == null || b['id'] == offline.branchId)
      .map(
        (b) => BranchAccess(
          branch: Branch(
            id: b['id'] as String,
            organizationId: organizationId,
            code: b['code'] as String,
            name: b['name'] as String,
            timezone: b['timezone'] as String,
          ),
          roles: [
            effective(
              b['id'] as String,
              offline?.permissions ?? (b['permissions'] as List),
            ),
          ],
        ),
      )
      .toList();
  if (branches.isEmpty) {
    throw const FormatException('No accessible branch is assigned.');
  }
  final selected =
      branchId != null && branches.any((b) => b.branch.id == branchId)
      ? branchId
      : branches.first.branch.id;
  return AuthSession(
    user: AppUser(
      firebaseUid: value['identityId'] as String,
      email: value['email'] as String,
      displayName: value['displayName'] as String,
      organizations: [
        OrganizationAccess(
          appUserId: value['userId'] as String,
          organization: Organization(
            id: organizationId,
            code: org['code'] as String,
            name: org['name'] as String,
            timezone: org['timezone'] as String,
          ),
          status: UserAccountStatus.active,
          organizationRoles: offline == null
              ? [
                  effective(
                    'organization',
                    value['organizationPermissions'] as List,
                  ),
                ]
              : [],
          branches: branches,
        ),
      ],
    ),
    activeOrganizationId: organizationId,
    activeBranchId: selected,
  );
}
