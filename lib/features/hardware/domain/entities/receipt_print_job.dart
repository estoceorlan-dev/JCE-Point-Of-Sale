enum ReceiptCopyType {
  original('original'),
  reprint('reprint');

  const ReceiptCopyType(this.databaseValue);

  final String databaseValue;

  static ReceiptCopyType fromDatabase(String value) => values.firstWhere(
    (candidate) => candidate.databaseValue == value,
    orElse: () => ReceiptCopyType.original,
  );
}

enum ReceiptPrintJobStatus {
  pending('pending'),
  processing('processing'),
  succeeded('succeeded'),
  retryableFailure('retryable_failure'),
  permanentFailure('permanent_failure');

  const ReceiptPrintJobStatus(this.databaseValue);

  final String databaseValue;

  static ReceiptPrintJobStatus fromDatabase(String value) => values.firstWhere(
    (candidate) => candidate.databaseValue == value,
    orElse: () => ReceiptPrintJobStatus.pending,
  );
}

class ReceiptPrintJob {
  const ReceiptPrintJob({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.registerId,
    required this.saleId,
    required this.copyType,
    required this.documentText,
    required this.status,
    required this.attemptCount,
    required this.requestedByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.nextAttemptAt,
    this.lastError,
    this.printedAt,
  });

  final String id;
  final String organizationId;
  final String branchId;
  final String registerId;
  final String saleId;
  final ReceiptCopyType copyType;
  final String documentText;
  final ReceiptPrintJobStatus status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final String requestedByUserId;
  final DateTime? printedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ReceiptPrintRequest {
  const ReceiptPrintRequest({
    required this.saleId,
    required this.registerId,
    required this.documentText,
    required this.copyType,
  });

  final String saleId;
  final String registerId;
  final String documentText;
  final ReceiptCopyType copyType;
}

class ReceiptDeliveryResult {
  const ReceiptDeliveryResult({
    required this.screenReceiptAvailable,
    this.jobId,
    this.printed = false,
    this.queuedForRetry = false,
    this.message,
  });

  final bool screenReceiptAvailable;
  final String? jobId;
  final bool printed;
  final bool queuedForRetry;
  final String? message;
}
