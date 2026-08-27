import '../../../../core/error/failures.dart';

enum SalePaymentMethod {
  cash('cash', 'Cash'),
  card('card', 'Card'),
  eWallet('e_wallet', 'E-wallet');

  const SalePaymentMethod(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static SalePaymentMethod fromDatabase(String value) {
    return values.firstWhere(
      (method) => method.databaseValue == value,
      orElse: () => SalePaymentMethod.cash,
    );
  }
}

class PaymentTender {
  const PaymentTender({
    required this.method,
    required this.tenderedAmountMinor,
    this.reference,
  });

  final SalePaymentMethod method;
  final int tenderedAmountMinor;
  final String? reference;
}

class AppliedPayment {
  const AppliedPayment({
    required this.method,
    required this.tenderedAmountMinor,
    required this.appliedAmountMinor,
    required this.changeAmountMinor,
    this.reference,
  });

  final SalePaymentMethod method;
  final int tenderedAmountMinor;
  final int appliedAmountMinor;
  final int changeAmountMinor;
  final String? reference;
}

class PaymentReconciliation {
  const PaymentReconciliation({
    required this.payments,
    required this.tenderedMinor,
    required this.appliedMinor,
    required this.changeMinor,
  });

  final List<AppliedPayment> payments;
  final int tenderedMinor;
  final int appliedMinor;
  final int changeMinor;
}

abstract final class PaymentCalculator {
  static PaymentReconciliation reconcile({
    required int totalMinor,
    required List<PaymentTender> tenders,
  }) {
    if (totalMinor <= 0) {
      throw const ValidationFailure(
        'The sale total must be greater than zero.',
      );
    }
    if (tenders.isEmpty) {
      throw const ValidationFailure('Add at least one payment.');
    }
    final methods = <SalePaymentMethod>{};
    for (final tender in tenders) {
      if (!methods.add(tender.method)) {
        throw const ValidationFailure('Use each payment method only once.');
      }
      if (tender.tenderedAmountMinor <= 0) {
        throw const ValidationFailure(
          'Payment amounts must be greater than zero.',
        );
      }
    }
    final nonCash = tenders.where(
      (tender) => tender.method != SalePaymentMethod.cash,
    );
    final nonCashTotal = nonCash.fold<int>(
      0,
      (total, tender) => total + tender.tenderedAmountMinor,
    );
    if (nonCashTotal > totalMinor) {
      throw const ValidationFailure(
        'Card and e-wallet payments exceed the sale total.',
      );
    }
    final remaining = totalMinor - nonCashTotal;
    final cash = tenders
        .where((tender) => tender.method == SalePaymentMethod.cash)
        .firstOrNull;
    if (remaining > 0 && cash == null) {
      throw const ValidationFailure(
        'Payment totals must cover the sale total.',
      );
    }
    if (cash != null && cash.tenderedAmountMinor < remaining) {
      throw const ValidationFailure(
        'Cash tender is less than the remaining balance.',
      );
    }
    if (remaining == 0 && cash != null) {
      throw const ValidationFailure(
        'Remove cash when non-cash payments cover the total.',
      );
    }
    final applied = <AppliedPayment>[
      for (final tender in nonCash)
        AppliedPayment(
          method: tender.method,
          tenderedAmountMinor: tender.tenderedAmountMinor,
          appliedAmountMinor: tender.tenderedAmountMinor,
          changeAmountMinor: 0,
          reference: tender.reference,
        ),
      if (cash != null)
        AppliedPayment(
          method: SalePaymentMethod.cash,
          tenderedAmountMinor: cash.tenderedAmountMinor,
          appliedAmountMinor: remaining,
          changeAmountMinor: cash.tenderedAmountMinor - remaining,
          reference: cash.reference,
        ),
    ];
    final tenderedTotal = applied.fold<int>(
      0,
      (total, payment) => total + payment.tenderedAmountMinor,
    );
    final appliedTotal = applied.fold<int>(
      0,
      (total, payment) => total + payment.appliedAmountMinor,
    );
    if (appliedTotal != totalMinor) {
      throw const ValidationFailure(
        'Applied payments must equal the sale total.',
      );
    }
    return PaymentReconciliation(
      payments: applied,
      tenderedMinor: tenderedTotal,
      appliedMinor: appliedTotal,
      changeMinor: tenderedTotal - appliedTotal,
    );
  }
}
