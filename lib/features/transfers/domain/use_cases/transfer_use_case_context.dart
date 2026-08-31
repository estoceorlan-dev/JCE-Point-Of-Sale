import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';

Result<BusinessContext, Failure> requireTransferContext({
  required AuthSession? session,
  required RequirePermissionUseCase requirePermission,
  required AppPermission permission,
}) {
  if (session == null) {
    return const Result.failure(
      AuthorizationFailure('Authentication is required.'),
    );
  }
  final result = requirePermission(
    session: session,
    permission: permission,
    organizationId: session.activeOrganizationId,
    branchId: session.activeBranchId,
  );
  if (result case FailureResult(:final failure)) {
    return Result.failure(failure);
  }
  return Result.success(
    BusinessContext(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      actorUserId: session.activeOrganization.appUserId,
    ),
  );
}
