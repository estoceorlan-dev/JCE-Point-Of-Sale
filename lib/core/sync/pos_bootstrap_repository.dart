import '../../shared/models/business_context.dart';
import '../error/failure.dart';
import '../error/result.dart';

enum PosBootstrapStatus { notProvisioned, preparing, ready, failed }

class PosBootstrapProgress {
  const PosBootstrapProgress({
    required this.status,
    this.collection,
    this.completedCollections = 0,
    this.totalCollections = 15,
    this.message,
  });

  final PosBootstrapStatus status;
  final String? collection;
  final int completedCollections;
  final int totalCollections;
  final String? message;

  double get fraction =>
      totalCollections == 0 ? 0 : completedCollections / totalCollections;
}

abstract interface class PosBootstrapRepository {
  Stream<PosBootstrapProgress> watchProgress(BusinessContext context);

  Future<bool> hasUsableCache(BusinessContext context);

  Future<Result<void, Failure>> provision(
    BusinessContext context, {
    bool force = false,
  });
}
