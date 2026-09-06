import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../entities/catalog_drafts.dart';
import '../repositories/tax_categories_repository.dart';

class ManageTaxCategoryUseCase {
  const ManageTaxCategoryUseCase(this._repository);
  final TaxCategoriesRepository _repository;

  Future<Result<String, Failure>> save({
    required AuthSession? session,
    required TaxCategoryDraft draft,
    String? id,
  }) async {
    if (session == null || !session.can(AppPermission.manageProducts)) {
      return const Result.failure(
        AuthorizationFailure('Product management permission is required.'),
      );
    }
    final value = draft.normalized();
    if (!RegExp(r'^[A-Z0-9_-]{1,32}$').hasMatch(value.code) ||
        value.name.length < 2 ||
        value.name.length > 80 ||
        value.rateBasisPoints < 0 ||
        value.rateBasisPoints > 10000) {
      return const Result.failure(
        ValidationFailure(
          'Enter a code, a name of 2–80 characters, and a tax rate from 0 to 100%.',
        ),
      );
    }
    return _repository.save(context: _context(session), draft: value, id: id);
  }

  Future<Result<void, Failure>> setArchived({
    required AuthSession? session,
    required String id,
    required bool archived,
  }) async {
    if (session == null || !session.can(AppPermission.manageProducts)) {
      return const Result.failure(
        AuthorizationFailure('Product management permission is required.'),
      );
    }
    return _repository.setArchived(
      context: _context(session),
      id: id,
      archived: archived,
    );
  }

  BusinessContext _context(AuthSession session) => BusinessContext(
    organizationId: session.activeOrganizationId,
    branchId: session.activeBranchId,
    actorUserId: session.activeOrganization.appUserId,
  );
}
