import 'cart.dart';
import 'payment.dart';
import 'sale_status.dart';
import 'sale_correction.dart';

class SaleItem {
  const SaleItem({
    required this.id,
    required this.productId,
    required this.stockLocationId,
    required this.lineNumber,
    required this.productName,
    required this.sku,
    required this.unitName,
    required this.quantityMilli,
    required this.unitPriceMinor,
    required this.unitCostMinor,
    required this.taxRateBasisPoints,
    required this.taxInclusive,
    required this.grossAmountMinor,
    required this.discountAmountMinor,
    required this.netAmountMinor,
    required this.taxAmountMinor,
    required this.totalAmountMinor,
    this.barcode,
    this.returnedQuantityMilli = 0,
  });

  final String id;
  final String productId;
  final String stockLocationId;
  final int lineNumber;
  final String productName;
  final String sku;
  final String? barcode;
  final String unitName;
  final int quantityMilli;
  final int unitPriceMinor;
  final int unitCostMinor;
  final int taxRateBasisPoints;
  final bool taxInclusive;
  final int grossAmountMinor;
  final int discountAmountMinor;
  final int netAmountMinor;
  final int taxAmountMinor;
  final int totalAmountMinor;
  final int returnedQuantityMilli;

  int get returnableQuantityMilli => quantityMilli - returnedQuantityMilli;
}

class SalePayment {
  const SalePayment({
    required this.id,
    required this.method,
    required this.tenderedAmountMinor,
    required this.appliedAmountMinor,
    required this.changeAmountMinor,
    this.reference,
  });

  final String id;
  final SalePaymentMethod method;
  final int tenderedAmountMinor;
  final int appliedAmountMinor;
  final int changeAmountMinor;
  final String? reference;
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.branchId,
    required this.registerId,
    required this.registerName,
    required this.receiptNumber,
    required this.status,
    required this.cashierUserId,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.tenderedMinor,
    required this.changeMinor,
    required this.completedAt,
    required this.items,
    required this.payments,
    this.shiftId,
    this.discountApprovedByUserId,
    this.corrections = const [],
  });

  final String id;
  final String branchId;
  final String registerId;
  final String registerName;
  final String? shiftId;
  final String receiptNumber;
  final SaleStatus status;
  final String cashierUserId;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final int tenderedMinor;
  final int changeMinor;
  final DateTime completedAt;
  final List<SaleItem> items;
  final List<SalePayment> payments;
  final String? discountApprovedByUserId;
  final List<SaleCorrectionRecord> corrections;
}

class CheckoutDraft {
  const CheckoutDraft({
    required this.cart,
    required this.tenders,
    required this.deviceId,
    this.operationId,
  });

  final Cart cart;
  final List<PaymentTender> tenders;
  final String deviceId;
  final String? operationId;
}

class CheckoutResult {
  const CheckoutResult({required this.saleId, required this.receiptNumber});

  final String saleId;
  final String receiptNumber;
}

class DiscountPolicy {
  const DiscountPolicy({this.approvalThresholdBasisPoints});

  final int? approvalThresholdBasisPoints;
}
