import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/customer.dart';
import '../repositories/customers_repository.dart';
import 'customer_use_case_context.dart';

class CreateCustomerUseCase {
  const CreateCustomerUseCase({
    required CustomersRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final CustomersRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required CustomerDraft draft,
  }) {
    final context = requireCustomerContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageCustomers,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.createCustomer(
      context: context.valueOrNull!,
      draft: draft,
    );
  }
}
