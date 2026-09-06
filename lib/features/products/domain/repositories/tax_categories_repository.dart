import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/catalog_drafts.dart';

abstract interface class TaxCategoriesRepository {
  Future<Result<String, Failure>> save({
    required BusinessContext context,
    required TaxCategoryDraft draft,
    String? id,
  });

  Future<Result<void, Failure>> setArchived({
    required BusinessContext context,
    required String id,
    required bool archived,
  });
}
