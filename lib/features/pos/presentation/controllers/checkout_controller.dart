import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/providers/app_providers.dart';
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
    required bool externalPaymentsConfirmed,
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
      final cartController = ref.read(cartControllerProvider.notifier);
      final refreshed = await cartController.refresh();
      if (refreshed case FailureResult(:final failure)) {
        result = Result.failure(failure);
        state = AsyncError(failure, failure.stackTrace ?? StackTrace.current);
        _submitting = false;
        return result;
      }
      final deviceId = await ref.read(currentDeviceIdProvider.future);
      final context = ref.read(businessContextProvider);
      if (context == null) {
        throw const AuthorizationFailure(
          'Choose an organization and branch before checkout.',
        );
      }
      final attemptResult = await ref
          .read(posCartRepositoryProvider)
          .prepareCheckoutAttempt(
            context: context,
            deviceId: deviceId,
            tenders: tenders,
            externalPaymentsConfirmed: externalPaymentsConfirmed,
          );
      if (attemptResult case FailureResult(:final failure)) {
        result = Result.failure(failure);
        state = AsyncError(failure, failure.stackTrace ?? StackTrace.current);
        _submitting = false;
        return result;
      }
      final attempt = attemptResult.valueOrNull!;
      cartController.recordCheckoutAttempt(attempt);
      result = await ref.read(checkoutSaleUseCaseProvider)(
        session: ref.read(activePosSessionProvider),
        draft: CheckoutDraft(
          cart: ref.read(cartControllerProvider),
          tenders: tenders,
          deviceId: deviceId,
          customerId: ref.read(cartControllerProvider).customerId,
          operationId: attempt.operationId,
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
      ref.read(cartControllerProvider.notifier).clearAfterCheckout();
      ref.read(selectedCheckoutCustomerProvider.notifier).state = null;
    }
    _submitting = false;
    return result;
  }
}
