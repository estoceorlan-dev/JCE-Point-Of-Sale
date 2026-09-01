import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/customer.dart';
import '../providers/customers_providers.dart';

final customerMutationControllerProvider =
    AsyncNotifierProvider<CustomerMutationController, void>(
      CustomerMutationController.new,
    );

class CustomerMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<String, Failure>> create(CustomerDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(createCustomerUseCaseProvider)(
      session: ref.read(activeCustomerSessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> updateCustomer(
    CustomerSummary customer,
    CustomerDraft draft,
  ) => _run(
    () => ref.read(updateCustomerUseCaseProvider)(
      session: ref.read(activeCustomerSessionProvider),
      customer: customer,
      draft: draft,
    ),
  );

  Future<Result<void, Failure>> archive(CustomerSummary customer) => _run(
    () => ref
        .read(customerLifecycleUseCaseProvider)
        .archive(
          session: ref.read(activeCustomerSessionProvider),
          customer: customer,
        ),
  );

  Future<Result<void, Failure>> restore(CustomerSummary customer) => _run(
    () => ref
        .read(customerLifecycleUseCaseProvider)
        .restore(
          session: ref.read(activeCustomerSessionProvider),
          customer: customer,
        ),
  );

  Future<Result<void, Failure>> anonymize(
    CustomerSummary customer,
    String reason,
  ) => _run(
    () => ref.read(anonymizeCustomerUseCaseProvider)(
      session: ref.read(activeCustomerSessionProvider),
      customer: customer,
      reason: reason,
    ),
  );

  Future<Result<void, Failure>> merge(
    CustomerSummary source,
    CustomerSummary target,
  ) => _run(
    () => ref.read(mergeCustomersUseCaseProvider)(
      session: ref.read(activeCustomerSessionProvider),
      source: source,
      target: target,
    ),
  );

  Future<Result<void, Failure>> addNote(String customerId, String body) => _run(
    () => ref.read(addCustomerNoteUseCaseProvider)(
      session: ref.read(activeCustomerSessionProvider),
      customerId: customerId,
      body: body,
    ),
  );

  Future<Result<void, Failure>> adjustLoyalty(
    String customerId,
    int pointsDelta,
    String reason,
  ) => _run(
    () => ref.read(adjustLoyaltyPointsUseCaseProvider)(
      session: ref.read(activeCustomerSessionProvider),
      customerId: customerId,
      pointsDelta: pointsDelta,
      reason: reason,
    ),
  );

  Future<Result<void, Failure>> _run(
    Future<Result<void, Failure>> Function() operation,
  ) async {
    state = const AsyncLoading();
    final result = await operation();
    _finish(result);
    return result;
  }

  void _finish<T>(Result<T, Failure> result) {
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) =>
          AsyncError(failure, failure.stackTrace ?? StackTrace.current),
    );
  }
}
