import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../domain/entities/catalog_category.dart';
import '../../domain/entities/catalog_tax_category.dart';
import '../../domain/entities/catalog_unit.dart';
import '../../domain/entities/product_query.dart';
import '../../domain/entities/product_summary.dart';
import '../controllers/product_mutation_controller.dart';
import '../providers/products_providers.dart';
import '../widgets/catalog_management_dialog.dart';
import '../widgets/product_details_dialog.dart';
import '../widgets/product_filters.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/product_table.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();
  ProductQuery _query = const ProductQuery();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productPageProvider(_query));
    final categories = ref.watch(productCategoriesProvider).value ?? const [];
    final units = ref.watch(productUnitsProvider).value ?? const [];
    final taxCategories =
        ref.watch(productTaxCategoriesProvider).value ?? const [];
    ref.watch(pendingProductImageUploadProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < AppBreakpoints.compact
            ? AppSpacing.lg
            : AppSpacing.xxl;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productPageProvider(_query));
            ref.invalidate(pendingProductImageUploadProvider);
            await ref.read(productPageProvider(_query).future);
          },
          child: ListView(
            padding: EdgeInsets.all(padding),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      onCreate: () =>
                          _openCreate(categories, units, taxCategories),
                      onManageCatalog: _openCatalogManagement,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ProductFilters(
                      searchController: _searchController,
                      categories: categories,
                      categoryId: _query.categoryId,
                      includeArchived: _query.includeArchived,
                      onSearchChanged: _search,
                      onCategoryChanged: (categoryId) {
                        setState(() {
                          _query = _query.copyWith(
                            categoryId: categoryId,
                            clearCategory: categoryId == null,
                            offset: 0,
                            pageSize: 30,
                          );
                        });
                      },
                      onIncludeArchivedChanged: (value) {
                        setState(() {
                          _query = _query.copyWith(
                            includeArchived: value,
                            offset: 0,
                            pageSize: 30,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    products.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xxl),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => _CatalogError(error: error),
                      data: (page) => Column(
                        children: [
                          ProductTable(
                            products: page.items,
                            onView: _openDetails,
                            onEdit: (summary) => _openEdit(
                              summary,
                              categories,
                              units,
                              taxCategories,
                            ),
                            onArchiveToggle: _toggleArchive,
                          ),
                          if (page.hasMore) ...[
                            const SizedBox(height: AppSpacing.lg),
                            OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _query = _query.copyWith(
                                  pageSize: _query.pageSize + 30,
                                );
                              }),
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Load more'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _query = _query.copyWith(search: value, offset: 0, pageSize: 30);
      });
    });
  }

  Future<void> _openCreate(
    List<CatalogCategory> categories,
    List<CatalogUnit> units,
    List<CatalogTaxCategory> taxCategories,
  ) async {
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create at least one unit first.')),
      );
      await _openCatalogManagement();
      return;
    }
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductFormDialog(
        categories: categories,
        units: units,
        taxCategories: taxCategories,
      ),
    );
  }

  Future<void> _openEdit(
    ProductSummary summary,
    List<CatalogCategory> categories,
    List<CatalogUnit> units,
    List<CatalogTaxCategory> taxCategories,
  ) async {
    final product = await ref.read(productDetailsProvider(summary.id).future);
    if (!mounted || product == null) {
      return;
    }
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductFormDialog(
        categories: categories,
        units: units,
        taxCategories: taxCategories,
        product: product,
        summary: summary,
      ),
    );
  }

  Future<void> _openDetails(ProductSummary summary) {
    return showDialog<void>(
      context: context,
      builder: (context) => ProductDetailsDialog(summary: summary),
    );
  }

  Future<void> _openCatalogManagement() {
    return showDialog<void>(
      context: context,
      builder: (context) => const CatalogManagementDialog(),
    );
  }

  Future<void> _toggleArchive(ProductSummary product) async {
    final archived = product.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: archived ? 'Archive product?' : 'Restore product?',
        message: archived
            ? '${product.name} will no longer appear in active product searches.'
            : '${product.name} will return to the active catalog.',
        confirmLabel: archived ? 'Archive' : 'Restore',
        destructive: archived,
        icon: archived ? Icons.archive_outlined : Icons.unarchive_outlined,
      ),
    );
    if (confirmed != true) {
      return;
    }
    final result = await ref
        .read(productMutationControllerProvider.notifier)
        .setArchived(productId: product.id, archived: archived);
    if (!mounted) {
      return;
    }
    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archived ? 'Product archived.' : 'Product restored.'),
        ),
      ),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate, required this.onManageCatalog});

  final VoidCallback onCreate;
  final VoidCallback onManageCatalog;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product catalog',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Manage organization products, branch pricing, barcodes, and offline changes.',
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onManageCatalog,
          icon: const Icon(Icons.tune),
          label: const Text('Categories & units'),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('New product'),
        ),
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text('The local product catalog could not be loaded: $error'),
      ),
    );
  }
}
