import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/branch_business_day.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../domain/entities/branch_profile.dart';
import '../repositories/branches_repository.dart';

class CreateBranchUseCase {
  const CreateBranchUseCase(this._repository);

  final BranchAdministrationRepository _repository;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required BranchDraft draft,
  }) async {
    final authorization = _authorize(session);
    if (authorization case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final validated = _validate(draft);
    if (validated case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.createBranch(
      context: authorization.valueOrNull!,
      draft: validated.valueOrNull!,
    );
  }
}

class UpdateBranchUseCase {
  const UpdateBranchUseCase(this._repository);

  final BranchAdministrationRepository _repository;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required String branchId,
    required int expectedVersion,
    required BranchDraft draft,
  }) async {
    final authorization = _authorize(session);
    if (authorization case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final validated = _validate(draft);
    if (validated case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.updateBranch(
      context: authorization.valueOrNull!,
      branchId: branchId,
      expectedVersion: expectedVersion,
      draft: validated.valueOrNull!,
    );
  }
}

Result<BusinessContext, Failure> _authorize(AuthSession? session) {
  if (session == null) {
    return const Result.failure(
      AuthorizationFailure('Authentication is required.'),
    );
  }
  if (!session.canOrganizationWide(AppPermission.manageBranches)) {
    return const Result.failure(
      AuthorizationFailure(
        'An organization-wide branches.manage role is required.',
      ),
    );
  }
  return Result.success(
    BusinessContext(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      actorUserId: session.activeOrganization.appUserId,
    ),
  );
}

Result<BranchDraft, Failure> _validate(BranchDraft draft) {
  final value = draft.normalized();
  if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{1,19}$').hasMatch(value.code)) {
    return const Result.failure(
      ValidationFailure(
        'Branch code must be 2–20 uppercase letters, numbers, or hyphens.',
      ),
    );
  }
  if (value.name.length < 2 || value.name.length > 80) {
    return const Result.failure(
      ValidationFailure('Branch name must contain 2–80 characters.'),
    );
  }
  if (!BranchBusinessDay.isValidTimezone(value.timezone)) {
    return const Result.failure(
      ValidationFailure('Enter a valid IANA timezone such as Asia/Manila.'),
    );
  }
  final email = value.email;
  if (email != null &&
      (email.length > 254 ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
    return const Result.failure(
      ValidationFailure('Enter a valid branch email address.'),
    );
  }
  if (value.phone != null &&
      !RegExp(r'^\+?[0-9 ()-]{7,30}$').hasMatch(value.phone!)) {
    return const Result.failure(
      ValidationFailure('Enter a valid branch phone number.'),
    );
  }
  if ((value.receiptDisplayName?.length ?? 0) > 80) {
    return const Result.failure(
      ValidationFailure('Receipt display name must not exceed 80 characters.'),
    );
  }
  return Result.success(value);
}
