import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/remote/firebase_functions_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/offline_first_users_repository.dart';
import '../../data/services/cloud_staff_invitation_service.dart';
import '../../domain/entities/staff_account.dart';
import '../../domain/repositories/users_repository.dart';
import '../../domain/services/staff_invitation_service.dart';
import '../../domain/usecases/manage_roles_usecase.dart';
import '../../domain/usecases/manage_staff_usecase.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return OfflineFirstUsersRepository(
    database: ref.watch(appDatabaseProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final staffDirectoryProvider = StreamProvider<List<StaffAccount>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref.watch(usersRepositoryProvider).watchUsers(context: context);
});

final roleDirectoryProvider = StreamProvider.family<List<RoleDefinition>, bool>(
  (ref, includeArchived) {
    final context = ref.watch(businessContextProvider);
    if (context == null) return Stream.value(const []);
    return ref
        .watch(usersRepositoryProvider)
        .watchRoles(context: context, includeArchived: includeArchived);
  },
);

final manageStaffUseCaseProvider = Provider<ManageStaffUseCase>((ref) {
  return ManageStaffUseCase(ref.watch(usersRepositoryProvider));
});

final manageRolesUseCaseProvider = Provider<ManageRolesUseCase>((ref) {
  return ManageRolesUseCase(ref.watch(usersRepositoryProvider));
});

final activeUserAdminSessionProvider = Provider((ref) {
  return ref.watch(authControllerProvider).asData?.value;
});

final staffInvitationServiceProvider = Provider<StaffInvitationService>((ref) {
  final config = ref.watch(appConfigProvider);
  return CloudStaffInvitationService(
    functions: ref.watch(firebaseFunctionsProvider),
    generateFunctionName: config.generateStaffInviteFunctionName,
    acceptFunctionName: config.acceptStaffInviteFunctionName,
    demoMode: config.enableDemoAuth,
  );
});
