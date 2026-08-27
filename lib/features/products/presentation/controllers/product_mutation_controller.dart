import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/catalog_drafts.dart';
import '../../domain/entities/product_draft.dart';
import '../../domain/entities/product_price.dart';
import '../providers/products_providers.dart';

final productMutationControllerProvider =
    AsyncNotifierProvider<ProductMutationController, void>(
      ProductMutationController.new,
    );

class ProductMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<String, Failure>> createProduct(ProductDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(createProductUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(updateProductUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      productId: productId,
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<String, Failure>> addProductPrice({
    required String productId,
    required ProductPriceDraft draft,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(addProductPriceUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      productId: productId,
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> setArchived({
    required String productId,
    required bool archived,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(setProductArchivedUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      productId: productId,
      archived: archived,
    );
    _finish(result);
    return result;
  }

  Future<Result<String, Failure>> createCategory(String name) async {
    state = const AsyncLoading();
    final result = await ref.read(createCategoryUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      name: name,
    );
    _finish(result);
    return result;
  }

  Future<Result<String, Failure>> createUnit(UnitDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(createUnitUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> updateCategory({
    required String categoryId,
    required String name,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(updateCategoryUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      categoryId: categoryId,
      name: name,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> setCategoryArchived({
    required String categoryId,
    required bool archived,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(setCategoryArchivedUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      categoryId: categoryId,
      archived: archived,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> updateUnit({
    required String unitId,
    required UnitDraft draft,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(updateUnitUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      unitId: unitId,
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> setUnitArchived({
    required String unitId,
    required bool archived,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(setUnitArchivedUseCaseProvider)(
      session: ref.read(activeProductSessionProvider),
      unitId: unitId,
      archived: archived,
    );
    _finish(result);
    return result;
  }

  void _finish<S>(Result<S, Failure> result) {
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) =>
          AsyncError(failure, failure.stackTrace ?? StackTrace.current),
    );
  }
}
