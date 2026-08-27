import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/offline_first_branches_repository.dart';
import '../../domain/repositories/branches_repository.dart';
import '../../domain/usecases/update_branch_name_usecase.dart';

final branchesRepositoryProvider = Provider<BranchesRepository>((ref) {
  return OfflineFirstBranchesRepository(
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final updateBranchNameUseCaseProvider = Provider<UpdateBranchNameUseCase>((
  ref,
) {
  return UpdateBranchNameUseCase(
    repository: ref.watch(branchesRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});
