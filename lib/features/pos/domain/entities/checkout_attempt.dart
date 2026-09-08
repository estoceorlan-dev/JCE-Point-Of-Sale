import 'payment.dart';

/// A device-local checkout identity and its already-entered tenders.
///
/// When [externalPaymentApproved] is true, the attempt must survive failures
/// and restarts. It can only be retried with the same tenders so the cashier is
/// never prompted to charge an external terminal a second time.
class CheckoutAttempt {
  const CheckoutAttempt({
    required this.operationId,
    required this.tenders,
    required this.externalPaymentApproved,
    required this.attemptedAt,
  });

  final String operationId;
  final List<PaymentTender> tenders;
  final bool externalPaymentApproved;
  final DateTime attemptedAt;

  bool hasSameTenders(List<PaymentTender> other) {
    if (tenders.length != other.length) return false;
    for (var index = 0; index < tenders.length; index++) {
      final left = tenders[index];
      final right = other[index];
      if (left.method != right.method ||
          left.tenderedAmountMinor != right.tenderedAmountMinor ||
          _normalizedReference(left.reference) !=
              _normalizedReference(right.reference)) {
        return false;
      }
    }
    return true;
  }
}

String? _normalizedReference(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
