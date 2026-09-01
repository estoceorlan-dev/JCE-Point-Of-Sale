import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/supplier.dart';
import '../repositories/purchases_repository.dart';
import 'purchase_use_case_context.dart';

class ManageSupplierUseCase {
  const ManageSupplierUseCase({
    required PurchasesRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final PurchasesRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String, Failure>> create({
    required AuthSession? session,
    required SupplierDraft draft,
  }) {
    final context = requirePurchaseContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageSuppliers,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.createSupplier(
      context: context.valueOrNull!,
      draft: draft,
    );
  }

  Future<Result<void, Failure>> archive({
    required AuthSession? session,
    required Supplier supplier,
  }) {
    final context = requirePurchaseContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageSuppliers,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.archiveSupplier(
      context: context.valueOrNull!,
      supplierId: supplier.id,
      expectedVersion: supplier.version,
    );
  }
}
