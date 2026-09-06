import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/branch_profile.dart';

abstract interface class BranchesRepository {
  Future<Result<void, Failure>> updateBranchName({
    required BusinessContext context,
    required String name,
  });
}

abstract interface class BranchAdministrationRepository
    implements BranchesRepository {
  Stream<List<BranchProfile>> watchBranches({
    required BusinessContext context,
    BranchQuery query = const BranchQuery(),
  });

  Future<BranchProfile?> getBranch({
    required BusinessContext context,
    required String branchId,
  });

  Future<Result<String, Failure>> createBranch({
    required BusinessContext context,
    required BranchDraft draft,
  });

  Future<Result<void, Failure>> updateBranch({
    required BusinessContext context,
    required String branchId,
    required BranchDraft draft,
    required int expectedVersion,
  });

  Future<Result<void, Failure>> setBranchArchived({
    required BusinessContext context,
    required String branchId,
    required bool archived,
    required int expectedVersion,
  });
}
