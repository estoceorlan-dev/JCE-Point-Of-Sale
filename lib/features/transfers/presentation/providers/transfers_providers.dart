import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/data_sources/transfers_local_data_source.dart';
import '../../data/repositories/drift_transfers_repository.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/repositories/transfers_repository.dart';
import '../../domain/use_cases/configure_transfer_policy_use_case.dart';
import '../../domain/use_cases/create_transfer_draft_use_case.dart';
import '../../domain/use_cases/transfer_workflow_use_case.dart';

final transfersLocalDataSourceProvider = Provider<TransfersLocalDataSource>(
  (ref) => TransfersLocalDataSource(ref.watch(appDatabaseProvider)),
);

final transfersRepositoryProvider = Provider<TransfersRepository>((ref) {
  return DriftTransfersRepository(
    database: ref.watch(appDatabaseProvider),
    localDataSource: ref.watch(transfersLocalDataSourceProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final stockTransfersProvider = StreamProvider<List<StockTransfer>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref
      .watch(transfersRepositoryProvider)
      .watchTransfers(context: context);
});

final transferOptionsProvider = FutureProvider<TransferOptions>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Future.value(
      const TransferOptions(branches: [], locations: [], products: []),
    );
  }
  return ref.watch(transfersRepositoryProvider).getOptions(context: context);
});

final transferPolicyProvider = FutureProvider<TransferPolicy?>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref.watch(transfersRepositoryProvider).getPolicy(context: context);
});

final createTransferDraftUseCaseProvider = Provider<CreateTransferDraftUseCase>(
  (ref) => CreateTransferDraftUseCase(
    repository: ref.watch(transfersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final transferWorkflowUseCaseProvider = Provider<TransferWorkflowUseCase>(
  (ref) => TransferWorkflowUseCase(
    repository: ref.watch(transfersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final configureTransferPolicyUseCaseProvider =
    Provider<ConfigureTransferPolicyUseCase>(
      (ref) => ConfigureTransferPolicyUseCase(
        repository: ref.watch(transfersRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final activeTransferSessionProvider = Provider(
  (ref) => ref.watch(authControllerProvider).asData?.value,
);
