import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/stock_transfer.dart';
import '../repositories/transfers_repository.dart';
import 'transfer_use_case_context.dart';

class CreateTransferDraftUseCase {
  const CreateTransferDraftUseCase({
    required TransfersRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final TransfersRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required StockTransferDraft draft,
  }) {
    final context = requireTransferContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageInventory,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.createDraft(context: context.valueOrNull!, draft: draft);
  }
}
