import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/stock_transfer.dart';

abstract interface class TransfersRepository {
  Stream<List<StockTransfer>> watchTransfers({
    required BusinessContext context,
  });

  Future<StockTransfer?> getTransfer({
    required BusinessContext context,
    required String transferId,
  });

  Future<TransferOptions> getOptions({required BusinessContext context});

  Future<TransferPolicy?> getPolicy({required BusinessContext context});

  Future<Result<void, Failure>> configurePolicy({
    required BusinessContext context,
    required TransferPolicy policy,
  });

  Future<Result<String, Failure>> createDraft({
    required BusinessContext context,
    required StockTransferDraft draft,
  });

  Future<Result<void, Failure>> submit({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    String? operationId,
  });

  Future<Result<void, Failure>> approve({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    String? operationId,
  });

  Future<Result<void, Failure>> reject({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    required String reason,
    String? operationId,
  });

  Future<Result<void, Failure>> ship({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    String? operationId,
  });

  Future<Result<void, Failure>> receive({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    required TransferReceiptDraft draft,
  });

  Future<Result<void, Failure>> correctReceipt({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    required TransferCorrectionDraft draft,
    required String approvedByUserId,
  });

  Future<Result<void, Failure>> cancel({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    required String reason,
    String? operationId,
  });
}
