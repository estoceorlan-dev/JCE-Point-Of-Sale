import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../shifts/presentation/providers/shift_providers.dart';
import '../../../customers/presentation/providers/customers_providers.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/sale.dart';
import '../providers/pos_providers.dart';
import 'cart_controller.dart';

final checkoutControllerProvider =
    AsyncNotifierProvider<CheckoutController, void>(CheckoutController.new);

class CheckoutController extends AsyncNotifier<void> {
  bool _submitting = false;

  @override
  void build() {}

  Future<Result<CheckoutResult, Failure>> checkout({
    required List<PaymentTender> tenders,
    required bool approveDiscountAsManager,
  }) async {
    if (_submitting) {
      return const Result.failure(
        ConflictFailure('Checkout is already being processed.'),
      );
    }
    _submitting = true;
    state = const AsyncLoading();
    late final Result<CheckoutResult, Failure> result;
    try {
      final deviceId = await ref.read(currentDeviceIdProvider.future);
      final operationId = ref.read(idGeneratorProvider).newId();
      result = await ref.read(checkoutSaleUseCaseProvider)(
        session: ref.read(activePosSessionProvider),
        draft: CheckoutDraft(
          cart: ref.read(cartControllerProvider),
          tenders: tenders,
          deviceId: deviceId,
          customerId: ref.read(cartControllerProvider).customerId,
          operationId: operationId,
        ),
        approveDiscountAsManager: approveDiscountAsManager,
      );
    } catch (error, stackTrace) {
      result = Result.failure(FailureMapper.fromException(error, stackTrace));
    }
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) =>
          AsyncError(failure, failure.stackTrace ?? StackTrace.current),
    );
    if (result.isSuccess) {
      ref.read(cartControllerProvider.notifier).clear();
      ref.read(selectedCheckoutCustomerProvider.notifier).state = null;
    }
    _submitting = false;
    return result;
  }
}
