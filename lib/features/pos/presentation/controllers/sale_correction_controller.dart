import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../shifts/presentation/providers/shift_providers.dart';
import '../../domain/entities/sale_correction.dart';
import '../providers/pos_providers.dart';

final saleCorrectionControllerProvider =
    AsyncNotifierProvider<SaleCorrectionController, void>(
      SaleCorrectionController.new,
    );

class SaleCorrectionController extends AsyncNotifier<void> {
  bool _submitting = false;

  @override
  void build() {}

  Future<Result<SaleCorrectionResult, Failure>> correct({
    required String saleId,
    required SaleCorrectionType type,
    required List<SaleCorrectionLineDraft> lines,
    required List<RefundDraft> refunds,
    required String reasonCode,
    required String? notes,
    required bool approveAsManager,
  }) async {
    if (_submitting) {
      return const Result.failure(
        ConflictFailure('A sale correction is already being processed.'),
      );
    }
    _submitting = true;
    state = const AsyncLoading();
    late final Result<SaleCorrectionResult, Failure> result;
    try {
      final deviceId = await ref.read(currentDeviceIdProvider.future);
      result = await ref.read(correctSaleUseCaseProvider)(
        session: ref.read(activePosSessionProvider),
        draft: SaleCorrectionDraft(
          saleId: saleId,
          type: type,
          lines: lines,
          refunds: refunds,
          reasonCode: reasonCode,
          notes: notes,
          deviceId: deviceId,
          operationId: ref.read(idGeneratorProvider).newId(),
        ),
        approveAsManager: approveAsManager,
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
      ref.invalidate(recentSalesProvider);
      ref.invalidate(saleDetailsProvider(saleId));
    }
    _submitting = false;
    return result;
  }
}
