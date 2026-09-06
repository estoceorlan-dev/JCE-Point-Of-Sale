import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/user_account_status.dart';
import '../entities/staff_account.dart';

abstract interface class UsersRepository {
  Stream<List<StaffAccount>> watchUsers({required BusinessContext context});

  Stream<List<RoleDefinition>> watchRoles({
    required BusinessContext context,
    bool includeArchived = false,
  });

  Future<Result<String, Failure>> inviteUser({
    required BusinessContext context,
    required StaffDraft draft,
  });

  Future<Result<void, Failure>> updateUser({
    required BusinessContext context,
    required String userId,
    required String displayName,
    required String email,
    required int expectedVersion,
  });

  Future<Result<void, Failure>> replaceAssignments({
    required BusinessContext context,
    required String userId,
    required List<StaffAssignmentDraft> assignments,
  });

  Future<Result<void, Failure>> setUserStatus({
    required BusinessContext context,
    required String userId,
    required UserAccountStatus status,
    required int expectedVersion,
  });

  Future<Result<String, Failure>> createRole({
    required BusinessContext context,
    required RoleDraft draft,
  });

  Future<Result<void, Failure>> updateRole({
    required BusinessContext context,
    required String roleId,
    required RoleDraft draft,
    required int expectedVersion,
  });

  Future<Result<void, Failure>> setRoleArchived({
    required BusinessContext context,
    required String roleId,
    required bool archived,
    required int expectedVersion,
  });
}
