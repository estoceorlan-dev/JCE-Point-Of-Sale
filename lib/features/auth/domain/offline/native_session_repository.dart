import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';

class NativeAccess {
  const NativeAccess({
    required this.deploymentId,
    required this.identityId,
    required this.userId,
    required this.organizationId,
    required this.displayName,
    required this.organizationPermissions,
    required this.branches,
  });
  final String deploymentId;
  final String identityId;
  final String userId;
  final String organizationId;
  final String displayName;
  final Set<String> organizationPermissions;
  final List<NativeBranchAccess> branches;
}

class NativeBranchAccess {
  const NativeBranchAccess(this.id, this.name, this.permissions);
  final String id;
  final String name;
  final Set<String> permissions;
}

abstract interface class NativeSessionRepository {
  Future<Result<NativeAccess, Failure>> signIn(String email, String password);
  Future<Result<void, Failure>> signOut();
}
