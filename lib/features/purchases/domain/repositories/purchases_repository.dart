import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/goods_receipt.dart';
import '../entities/purchase_order.dart';
import '../entities/supplier.dart';

abstract interface class PurchasesRepository {
  Stream<List<Supplier>> watchSuppliers({required BusinessContext context});

  Stream<List<PurchaseOrder>> watchPurchaseOrders({
    required BusinessContext context,
  });

  Future<PurchaseOrder?> getPurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
  });

  Future<PurchaseOptions> getOptions({required BusinessContext context});

  Future<Result<String, Failure>> createSupplier({
    required BusinessContext context,
    required SupplierDraft draft,
  });

  Future<Result<void, Failure>> archiveSupplier({
    required BusinessContext context,
    required String supplierId,
    required int expectedVersion,
    String? operationId,
  });

  Future<Result<String, Failure>> createPurchaseOrder({
    required BusinessContext context,
    required PurchaseOrderDraft draft,
  });

  Future<Result<void, Failure>> submitPurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    String? operationId,
  });

  Future<Result<void, Failure>> approvePurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    String? operationId,
  });

  Future<Result<void, Failure>> cancelPurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    required String reason,
    String? operationId,
  });

  Future<Result<String, Failure>> receivePurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    required GoodsReceiptDraft draft,
  });
}
