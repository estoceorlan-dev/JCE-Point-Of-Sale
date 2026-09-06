import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../data/repositories/drift_register_administration_repository.dart';
import '../../domain/entities/register.dart';
import '../../domain/repositories/register_administration_repository.dart';
import '../../domain/use_cases/manage_register_use_case.dart';

final registerAdministrationRepositoryProvider =
    Provider<RegisterAdministrationRepository>(
      (ref) => DriftRegisterAdministrationRepository(
        database: ref.watch(appDatabaseProvider),
        ids: ref.watch(idGeneratorProvider),
        clock: ref.watch(appClockProvider),
      ),
    );
final manageRegisterUseCaseProvider = Provider<ManageRegisterUseCase>(
  (ref) => ManageRegisterUseCase(
    ref.watch(registerAdministrationRepositoryProvider),
  ),
);
final allRegistersProvider = StreamProvider<List<Register>>((ref) {
  final context = ref.watch(businessContextProvider);
  return context == null
      ? Stream.value(const [])
      : ref.watch(registerAdministrationRepositoryProvider).watchAll(context);
});
