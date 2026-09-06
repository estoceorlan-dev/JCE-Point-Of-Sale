import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/adapters/network_esc_pos_cash_drawer.dart';
import '../../data/adapters/network_esc_pos_receipt_printer.dart';
import '../../data/repositories/drift_pos_hardware_repository.dart';
import '../../data/services/receipt_print_queue_processor.dart';
import '../../domain/entities/register_hardware_profile.dart';
import '../../domain/repositories/pos_hardware_repository.dart';
import '../../domain/services/cash_drawer.dart';
import '../../domain/services/receipt_printer.dart';
import '../../domain/use_cases/configure_register_hardware_use_case.dart';
import '../../../../shared/models/business_context.dart';

final posHardwareRepositoryProvider = Provider<PosHardwareRepository>((ref) {
  return DriftPosHardwareRepository(
    database: ref.watch(appDatabaseProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final receiptPrinterProvider = Provider<ReceiptPrinter>(
  (ref) => const NetworkEscPosReceiptPrinter(),
);

final cashDrawerProvider = Provider<CashDrawer>(
  (ref) => const NetworkEscPosCashDrawer(),
);

final receiptPrintQueueProcessorProvider = Provider<ReceiptPrintQueueProcessor>(
  (ref) => ReceiptPrintQueueProcessor(
    repository: ref.watch(posHardwareRepositoryProvider),
    printer: ref.watch(receiptPrinterProvider),
    clock: ref.watch(appClockProvider),
  ),
);

final registerHardwareProfileProvider =
    StreamProvider.family<RegisterHardwareProfile?, String>((ref, registerId) {
      final session = ref.watch(authControllerProvider).asData?.value;
      if (session == null) return Stream.value(null);
      return ref
          .watch(posHardwareRepositoryProvider)
          .watchProfile(
            context: BusinessContext(
              organizationId: session.activeOrganizationId,
              branchId: session.activeBranchId,
              actorUserId: session.activeOrganization.appUserId,
            ),
            registerId: registerId,
          );
    });

final configureRegisterHardwareUseCaseProvider =
    Provider<ConfigureRegisterHardwareUseCase>(
      (ref) => ConfigureRegisterHardwareUseCase(
        repository: ref.watch(posHardwareRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );
