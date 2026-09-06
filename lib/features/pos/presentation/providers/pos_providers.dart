import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../branches/presentation/providers/branches_providers.dart';
import '../../../settings/domain/entities/operational_setting.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../hardware/data/adapters/keyboard_wedge_barcode_scanner.dart';
import '../../../hardware/domain/entities/barcode_scan.dart';
import '../../../hardware/domain/entities/register_hardware_profile.dart';
import '../../../hardware/presentation/providers/hardware_providers.dart';
import '../../../shifts/presentation/providers/shift_providers.dart';
import '../../data/data_sources/sales_local_data_source.dart';
import '../../data/repositories/drift_sales_repository.dart';
import '../../data/repositories/drift_pos_cart_repository.dart';
import '../../domain/entities/held_cart.dart';
import '../../domain/repositories/pos_cart_repository.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_product.dart';
import '../../domain/entities/sale_correction.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/services/receipt_renderer.dart';
import '../../domain/use_cases/checkout_sale_use_case.dart';
import '../../domain/use_cases/configure_discount_policy_use_case.dart';
import '../../domain/use_cases/configure_correction_policy_use_case.dart';
import '../../domain/use_cases/correct_sale_use_case.dart';
import '../../domain/use_cases/deliver_sale_receipt_use_case.dart';
import '../../domain/use_cases/open_sale_cash_drawer_use_case.dart';

final salesLocalDataSourceProvider = Provider<SalesLocalDataSource>((ref) {
  return SalesLocalDataSource(ref.watch(appDatabaseProvider));
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return DriftSalesRepository(
    database: ref.watch(appDatabaseProvider),
    localDataSource: ref.watch(salesLocalDataSourceProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final posCartRepositoryProvider = Provider<PosCartRepository>((ref) {
  return DriftPosCartRepository(
    database: ref.watch(appDatabaseProvider),
    salesLocalDataSource: ref.watch(salesLocalDataSourceProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final heldCartsProvider = StreamProvider<List<HeldCart>>((ref) async* {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    yield const <HeldCart>[];
    return;
  }
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  yield* ref
      .watch(posCartRepositoryProvider)
      .watchHeld(context: context, deviceId: deviceId);
});

final saleProductSearchProvider =
    StreamProvider.family<List<SaleProduct>, String>((ref, search) {
      final context = ref.watch(businessContextProvider);
      if (context == null) return Stream.value(const []);
      return ref
          .watch(salesRepositoryProvider)
          .watchSaleProducts(context: context, search: search);
    });

final recentSalesProvider = StreamProvider<List<SaleRecord>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref.watch(salesRepositoryProvider).watchRecentSales(context: context);
});

final saleProductBrowserProvider =
    StreamProvider.family<
      List<SaleProduct>,
      ({String search, String? categoryId})
    >((ref, query) {
      final context = ref.watch(businessContextProvider);
      if (context == null) return Stream.value(const []);
      return ref
          .watch(salesRepositoryProvider)
          .watchSaleProducts(
            context: context,
            search: query.search,
            categoryId: query.categoryId,
          );
    });

final saleDetailsProvider = FutureProvider.family<SaleRecord?, String>((
  ref,
  saleId,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref
      .watch(salesRepositoryProvider)
      .getSale(context: context, saleId: saleId);
});

final discountPolicyProvider = FutureProvider<DiscountPolicy?>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref.watch(salesRepositoryProvider).getDiscountPolicy(context: context);
});

final correctionPolicyProvider = FutureProvider<SaleCorrectionPolicy?>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref
      .watch(salesRepositoryProvider)
      .getCorrectionPolicy(context: context);
});

final returnDestinationsProvider = FutureProvider<List<ReturnDestination>>((
  ref,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value(const []);
  return ref
      .watch(salesRepositoryProvider)
      .getReturnDestinations(context: context);
});

final receiptRendererProvider = Provider<ReceiptRenderer>((ref) {
  final context = ref.watch(businessContextProvider);
  final profile = context == null
      ? null
      : ref.watch(branchProfileProvider(context.branchId)).asData?.value;
  final settings =
      ref.watch(operationalSettingsProvider).asData?.value ??
      OperationalSettings.defaults();
  return PlainTextReceiptRenderer(
    branchProfile: profile,
    header: settings.text(OperationalSettingKey.receiptHeader),
    footer: settings.text(OperationalSettingKey.receiptFooter),
    showTaxBreakdown: settings.boolean(
      OperationalSettingKey.receiptShowTaxBreakdown,
    ),
    paperWidthCharacters: settings.integer(
      OperationalSettingKey.receiptPaperWidth,
    )!,
  );
});

final correctionReceiptRendererProvider = Provider<CorrectionReceiptRenderer>(
  (ref) => const PlainTextCorrectionReceiptRenderer(),
);

final checkoutSaleUseCaseProvider = Provider<CheckoutSaleUseCase>(
  (ref) => CheckoutSaleUseCase(
    repository: ref.watch(salesRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final configureDiscountPolicyUseCaseProvider =
    Provider<ConfigureDiscountPolicyUseCase>(
      (ref) => ConfigureDiscountPolicyUseCase(
        repository: ref.watch(salesRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final correctSaleUseCaseProvider = Provider<CorrectSaleUseCase>(
  (ref) => CorrectSaleUseCase(
    repository: ref.watch(salesRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final configureCorrectionPolicyUseCaseProvider =
    Provider<ConfigureCorrectionPolicyUseCase>(
      (ref) => ConfigureCorrectionPolicyUseCase(
        repository: ref.watch(salesRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final activePosSessionProvider = Provider((ref) {
  return ref.watch(authControllerProvider).asData?.value;
});

final activeRegisterHardwareProfileProvider =
    FutureProvider<RegisterHardwareProfile?>((ref) async {
      final context = ref.watch(businessContextProvider);
      if (context == null) return null;
      final deviceId = await ref.watch(currentDeviceIdProvider.future);
      return ref
          .watch(posHardwareRepositoryProvider)
          .getProfileForDevice(
            organizationId: context.organizationId,
            branchId: context.branchId,
            deviceId: deviceId,
          );
    });

final keyboardWedgeScannerProvider =
    Provider.autoDispose<KeyboardWedgeBarcodeScanner>((ref) {
      final profile = ref.watch(activeRegisterHardwareProfileProvider).value;
      final scanner = KeyboardWedgeBarcodeScanner(
        interCharacterTimeout: Duration(
          milliseconds: profile?.scannerInterCharacterTimeoutMs ?? 80,
        ),
        duplicateSuppression: Duration(
          milliseconds: profile?.scannerDuplicateSuppressionMs ?? 350,
        ),
      );
      unawaited(scanner.start());
      ref.onDispose(() => unawaited(scanner.dispose()));
      return scanner;
    });

final barcodeScansProvider = StreamProvider.autoDispose<BarcodeScan>((ref) {
  return ref.watch(keyboardWedgeScannerProvider).scans;
});

final deliverSaleReceiptUseCaseProvider = Provider<DeliverSaleReceiptUseCase>(
  (ref) => DeliverSaleReceiptUseCase(
    repository: ref.watch(posHardwareRepositoryProvider),
    processor: ref.watch(receiptPrintQueueProcessorProvider),
    renderer: ref.watch(receiptRendererProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final openSaleCashDrawerUseCaseProvider = Provider<OpenSaleCashDrawerUseCase>(
  (ref) => OpenSaleCashDrawerUseCase(
    repository: ref.watch(posHardwareRepositoryProvider),
    cashDrawer: ref.watch(cashDrawerProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);
