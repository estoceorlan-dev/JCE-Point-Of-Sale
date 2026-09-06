import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/csv_import.dart';

abstract interface class CsvImportRepository {
  Future<Result<CsvImportPreview, Failure>> preview({
    required BusinessContext context,
    required CsvImportKind kind,
    required String source,
  });
  Future<Result<int, Failure>> confirm({
    required BusinessContext context,
    required CsvImportPreview preview,
  });
}
