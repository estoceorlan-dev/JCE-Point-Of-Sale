import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/models/business_context.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/customer.dart';
import '../repositories/customers_repository.dart';
import 'customer_use_case_context.dart';

class CustomerLifecycleUseCase {
  const CustomerLifecycleUseCase({
    required CustomersRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final CustomersRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> archive({
    required AuthSession? session,
    required CustomerSummary customer,
  }) => _run(
    session,
    (context) =>
        _repository.archiveCustomer(context: context, customer: customer),
  );

  Future<Result<void, Failure>> restore({
    required AuthSession? session,
    required CustomerSummary customer,
  }) => _run(
    session,
    (context) =>
        _repository.restoreCustomer(context: context, customer: customer),
  );

  Future<Result<void, Failure>> _run(
    AuthSession? session,
    Future<Result<void, Failure>> Function(BusinessContext context) operation,
  ) {
    final context = requireCustomerContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageCustomers,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return operation(context.valueOrNull!);
  }
}
