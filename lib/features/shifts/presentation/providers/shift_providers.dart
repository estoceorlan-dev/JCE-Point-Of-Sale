import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/data_sources/shift_local_data_source.dart';
import '../../data/repositories/drift_shift_repository.dart';
import '../../domain/entities/cash_shift.dart';
import '../../domain/entities/register.dart';
import '../../domain/repositories/shift_repository.dart';
import '../../domain/use_cases/assign_register_device_use_case.dart';
import '../../domain/use_cases/close_shift_use_case.dart';
import '../../domain/use_cases/configure_shift_policy_use_case.dart';
import '../../domain/use_cases/create_register_use_case.dart';
import '../../domain/use_cases/open_shift_use_case.dart';
import '../../domain/use_cases/post_cash_movement_use_case.dart';
import '../../domain/use_cases/require_open_shift_for_sale_use_case.dart';

final shiftLocalDataSourceProvider = Provider<ShiftLocalDataSource>((ref) {
  return ShiftLocalDataSource(ref.watch(appDatabaseProvider));
});

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return DriftShiftRepository(
    database: ref.watch(appDatabaseProvider),
    localDataSource: ref.watch(shiftLocalDataSourceProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final currentDeviceIdProvider = FutureProvider<String>((ref) {
  return ref.watch(deviceRegistrationRepositoryProvider).deviceId();
});

final registersProvider = StreamProvider<List<Register>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref.watch(shiftRepositoryProvider).watchRegisters(context: context);
});

final activeShiftProvider = StreamProvider<CashShift?>((ref) {
  final context = ref.watch(businessContextProvider);
  final deviceId = ref.watch(currentDeviceIdProvider).value;
  if (context == null || deviceId == null) return Stream.value(null);
  return ref
      .watch(shiftRepositoryProvider)
      .watchActiveShift(context: context, deviceId: deviceId);
});

final recentShiftsProvider = StreamProvider<List<CashShift>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref.watch(shiftRepositoryProvider).watchRecentShifts(context: context);
});

final shiftPolicyProvider = FutureProvider<ShiftPolicy?>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref.watch(shiftRepositoryProvider).getPolicy(context: context);
});

final createRegisterUseCaseProvider = Provider<CreateRegisterUseCase>(
  (ref) => CreateRegisterUseCase(
    repository: ref.watch(shiftRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final assignRegisterDeviceUseCaseProvider =
    Provider<AssignRegisterDeviceUseCase>(
      (ref) => AssignRegisterDeviceUseCase(
        repository: ref.watch(shiftRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final openShiftUseCaseProvider = Provider<OpenShiftUseCase>(
  (ref) => OpenShiftUseCase(
    repository: ref.watch(shiftRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final postCashMovementUseCaseProvider = Provider<PostCashMovementUseCase>(
  (ref) => PostCashMovementUseCase(
    repository: ref.watch(shiftRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final closeShiftUseCaseProvider = Provider<CloseShiftUseCase>(
  (ref) => CloseShiftUseCase(
    repository: ref.watch(shiftRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final configureShiftPolicyUseCaseProvider =
    Provider<ConfigureShiftPolicyUseCase>(
      (ref) => ConfigureShiftPolicyUseCase(
        repository: ref.watch(shiftRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final requireOpenShiftForSaleUseCaseProvider =
    Provider<RequireOpenShiftForSaleUseCase>(
      (ref) => RequireOpenShiftForSaleUseCase(
        repository: ref.watch(shiftRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final activeShiftSessionProvider = Provider((ref) {
  return ref.watch(authControllerProvider).asData?.value;
});
