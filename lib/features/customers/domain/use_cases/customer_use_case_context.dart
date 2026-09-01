import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';

Result<BusinessContext, Failure> requireCustomerContext({
  required AuthSession? session,
  required RequirePermissionUseCase requirePermission,
  required AppPermission permission,
}) {
  if (session == null) {
    return const Result.failure(
      AuthorizationFailure('Authentication is required.'),
    );
  }
  final context = BusinessContext(
    organizationId: session.activeOrganizationId,
    branchId: session.activeBranchId,
    actorUserId: session.activeOrganization.appUserId,
  );
  return requirePermission(
    session: session,
    permission: permission,
    organizationId: context.organizationId,
    branchId: context.branchId,
  ).fold(onSuccess: (_) => Result.success(context), onFailure: Result.failure);
}
