import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../entities/register.dart';
import '../repositories/register_administration_repository.dart';

class ManageRegisterUseCase {
  const ManageRegisterUseCase(this._repository);
  final RegisterAdministrationRepository _repository;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required Register register,
    required RegisterAction action,
    RegisterDraft? draft,
  }) async {
    if (session == null || !session.can(AppPermission.manageRegisters)) {
      return const Result.failure(
        AuthorizationFailure('Register management permission is required.'),
      );
    }
    if (register.organizationId != session.activeOrganizationId ||
        register.branchId != session.activeBranchId) {
      return const Result.failure(
        AuthorizationFailure('Select the register’s branch first.'),
      );
    }
    final normalized = draft == null
        ? null
        : RegisterDraft(
            code: draft.code.trim().toUpperCase(),
            name: draft.name.trim(),
          );
    if (action == RegisterAction.edit &&
        (normalized == null ||
            !RegExp(r'^[A-Z0-9_-]{2,20}$').hasMatch(normalized.code) ||
            normalized.name.length < 2 ||
            normalized.name.length > 80)) {
      return const Result.failure(
        ValidationFailure(
          'Enter a register code of 2–20 characters and a name of 2–80 characters.',
        ),
      );
    }
    return _repository.mutate(
      context: BusinessContext(
        organizationId: session.activeOrganizationId,
        branchId: session.activeBranchId,
        actorUserId: session.activeOrganization.appUserId,
      ),
      register: register,
      action: action,
      draft: normalized,
    );
  }
}
