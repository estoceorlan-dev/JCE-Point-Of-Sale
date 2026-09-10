import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/offline_first_branches_repository.dart';
import '../../data/data_sources/philippine_address_asset_data_source.dart';
import '../../data/repositories/asset_philippine_address_repository.dart';
import '../../domain/entities/philippine_address_catalog.dart';
import '../../domain/repositories/branches_repository.dart';
import '../../domain/repositories/philippine_address_repository.dart';
import '../../domain/usecases/update_branch_name_usecase.dart';
import '../../domain/entities/branch_profile.dart';
import '../../domain/usecases/save_branch_usecases.dart';
import '../../domain/usecases/set_branch_archived_usecase.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../shared/providers/app_providers.dart';

final branchesRepositoryProvider = Provider<BranchAdministrationRepository>((
  ref,
) {
  return OfflineFirstBranchesRepository(
    database: ref.watch(appDatabaseProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final philippineAddressRepositoryProvider =
    Provider<PhilippineAddressRepository>((ref) {
      return AssetPhilippineAddressRepository(
        dataSource: PhilippineAddressAssetDataSource(assetBundle: rootBundle),
      );
    });

final philippineAddressCatalogProvider =
    FutureProvider<PhilippineAddressCatalog>((ref) {
      return ref.watch(philippineAddressRepositoryProvider).loadCatalog();
    });

final branchDirectoryProvider =
    StreamProvider.family<List<BranchProfile>, BranchQuery>((ref, query) {
      final context = ref.watch(businessContextProvider);
      if (context == null) return Stream.value(const <BranchProfile>[]);
      return ref
          .watch(branchesRepositoryProvider)
          .watchBranches(context: context, query: query);
    });

final createBranchUseCaseProvider = Provider<CreateBranchUseCase>((ref) {
  return CreateBranchUseCase(ref.watch(branchesRepositoryProvider));
});

final branchProfileProvider = StreamProvider.family<BranchProfile?, String>((
  ref,
  id,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(null);
  return ref
      .watch(branchesRepositoryProvider)
      .watchBranches(
        context: context,
        query: const BranchQuery(includeArchived: true),
      )
      .map(
        (branches) => branches.where((branch) => branch.id == id).firstOrNull,
      );
});

final updateBranchUseCaseProvider = Provider<UpdateBranchUseCase>((ref) {
  return UpdateBranchUseCase(ref.watch(branchesRepositoryProvider));
});

final setBranchArchivedUseCaseProvider = Provider<SetBranchArchivedUseCase>((
  ref,
) {
  return SetBranchArchivedUseCase(ref.watch(branchesRepositoryProvider));
});

final activeBranchAdminSessionProvider = Provider((ref) {
  return ref.watch(authControllerProvider).asData?.value;
});

final updateBranchNameUseCaseProvider = Provider<UpdateBranchNameUseCase>((
  ref,
) {
  return UpdateBranchNameUseCase(
    repository: ref.watch(branchesRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});
