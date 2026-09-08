import '../../../../shared/models/permission.dart';
import '../../../../shared/models/user_account_status.dart';

class StaffAssignment {
  const StaffAssignment({
    required this.id,
    required this.userId,
    required this.roleId,
    required this.roleName,
    required this.version,
    this.branchId,
    this.branchName,
  });

  final String id;
  final String userId;
  final String roleId;
  final String roleName;
  final String? branchId;
  final String? branchName;
  final int version;
}

class StaffAccount {
  const StaffAccount({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.displayName,
    required this.status,
    required this.assignments,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.firebaseUid,
    this.invitedAt,
    this.activatedAt,
    this.pendingOperations = 0,
  });

  final String id;
  final String organizationId;
  final String? firebaseUid;
  final String email;
  final String displayName;
  final UserAccountStatus status;
  final List<StaffAssignment> assignments;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? invitedAt;
  final DateTime? activatedAt;
  final int pendingOperations;
}

class StaffDraft {
  const StaffDraft({
    required this.email,
    required this.displayName,
    required this.assignments,
  });

  final String email;
  final String displayName;
  final List<StaffAssignmentDraft> assignments;
}

class StaffAssignmentDraft {
  const StaffAssignmentDraft({required this.roleId, this.branchId});

  final String roleId;
  final String? branchId;
}

class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    required this.permissions,
    required this.isActive,
    required this.version,
    required this.assignmentCount,
    this.description,
  });

  final String id;
  final String organizationId;
  final String code;
  final String name;
  final String? description;
  final Set<AppPermission> permissions;
  final bool isActive;
  final int version;
  final int assignmentCount;
}

class RoleDraft {
  const RoleDraft({
    required this.code,
    required this.name,
    required this.permissions,
    this.description,
  });

  final String code;
  final String name;
  final String? description;
  final Set<AppPermission> permissions;
}
