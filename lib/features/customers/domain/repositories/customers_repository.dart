import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/customer.dart';

abstract interface class CustomersRepository {
  Stream<List<CustomerSummary>> watchCustomers({
    required BusinessContext context,
    String search = '',
    bool includeInactive = false,
  });

  Stream<CustomerProfile?> watchCustomerProfile({
    required BusinessContext context,
    required String customerId,
  });

  Future<Result<String, Failure>> createCustomer({
    required BusinessContext context,
    required CustomerDraft draft,
  });

  Future<Result<void, Failure>> updateCustomer({
    required BusinessContext context,
    required CustomerSummary customer,
    required CustomerDraft draft,
  });

  Future<Result<void, Failure>> archiveCustomer({
    required BusinessContext context,
    required CustomerSummary customer,
    String? operationId,
  });

  Future<Result<void, Failure>> restoreCustomer({
    required BusinessContext context,
    required CustomerSummary customer,
    String? operationId,
  });

  Future<Result<void, Failure>> anonymizeCustomer({
    required BusinessContext context,
    required CustomerSummary customer,
    required String reason,
    String? operationId,
  });

  Future<Result<void, Failure>> mergeCustomers({
    required BusinessContext context,
    required CustomerSummary source,
    required CustomerSummary target,
    String? operationId,
  });

  Future<Result<void, Failure>> addNote({
    required BusinessContext context,
    required String customerId,
    required String body,
    String? operationId,
  });

  Future<Result<void, Failure>> adjustLoyaltyPoints({
    required BusinessContext context,
    required String customerId,
    required int pointsDelta,
    required String reason,
    String? operationId,
  });
}
