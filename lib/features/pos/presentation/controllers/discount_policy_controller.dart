import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/sale.dart';
import '../providers/pos_providers.dart';

final discountPolicyControllerProvider =
    AsyncNotifierProvider<DiscountPolicyController, void>(
      DiscountPolicyController.new,
    );

class DiscountPolicyController extends AsyncNotifier<void> {
  bool _saving = false;

  @override
  void build() {}

  Future<Result<void, Failure>> save(DiscountPolicy policy) async {
    if (_saving) {
      return const Result.failure(
        ConflictFailure('The discount policy is already being saved.'),
      );
    }
    _saving = true;
    state = const AsyncLoading();
    final result = await ref.read(configureDiscountPolicyUseCaseProvider)(
      session: ref.read(activePosSessionProvider),
      policy: policy,
    );
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) =>
          AsyncError(failure, failure.stackTrace ?? StackTrace.current),
    );
    _saving = false;
    return result;
  }
}
