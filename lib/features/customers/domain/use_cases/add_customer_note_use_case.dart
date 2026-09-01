import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../repositories/customers_repository.dart';
import 'customer_use_case_context.dart';

class AddCustomerNoteUseCase {
  const AddCustomerNoteUseCase({
    required CustomersRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final CustomersRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required String customerId,
    required String body,
  }) {
    final context = requireCustomerContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageCustomers,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.addNote(
      context: context.valueOrNull!,
      customerId: customerId,
      body: body,
    );
  }
}
