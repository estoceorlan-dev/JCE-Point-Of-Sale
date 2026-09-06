import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../entities/csv_import.dart';
import '../repositories/csv_import_repository.dart';

class ImportCsvUseCase {
  const ImportCsvUseCase(this._repository);
  final CsvImportRepository _repository;

  Future<Result<CsvImportPreview, Failure>> preview({
    required AuthSession? session,
    required CsvImportKind kind,
    required String source,
  }) async {
    final context = _context(session, kind);
    if (context == null) {
      return const Result.failure(
        AuthorizationFailure('Import permission is required.'),
      );
    }
    return _repository.preview(context: context, kind: kind, source: source);
  }

  Future<Result<int, Failure>> confirm({
    required AuthSession? session,
    required CsvImportPreview preview,
  }) async {
    final context = _context(session, preview.kind);
    if (context == null) {
      return const Result.failure(
        AuthorizationFailure('Import permission is required.'),
      );
    }
    if (!preview.canConfirm) {
      return const Result.failure(
        ValidationFailure('Correct all import errors first.'),
      );
    }
    return _repository.confirm(context: context, preview: preview);
  }

  BusinessContext? _context(AuthSession? session, CsvImportKind kind) {
    final permission = kind == CsvImportKind.catalog
        ? AppPermission.manageProducts
        : AppPermission.manageInventory;
    if (session == null || !session.can(permission)) return null;
    return BusinessContext(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      actorUserId: session.activeOrganization.appUserId,
    );
  }
}
