import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../products/presentation/providers/products_providers.dart';
import '../../domain/entities/sale_product.dart';
import '../controllers/cart_controller.dart';

class ProductSearchPanel extends ConsumerStatefulWidget {
  const ProductSearchPanel({
    super.key,
    required this.searchController,
    required this.products,
    required this.onSearchChanged,
    required this.onSubmitted,
    this.onRetry,
    this.focusNode,
    this.fillHeight = false,
    this.categoryId,
    this.onCategoryChanged,
  });
  final TextEditingController searchController;
  final AsyncValue<List<SaleProduct>> products;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onRetry;
  final FocusNode? focusNode;
  final bool fillHeight;
  final String? categoryId;
  final ValueChanged<String?>? onCategoryChanged;

  @override
  ConsumerState<ProductSearchPanel> createState() => _ProductSearchPanelState();
}

class _ProductSearchPanelState extends ConsumerState<ProductSearchPanel> {
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    final categories = widget.onCategoryChanged == null
        ? null
        : ref.watch(productCategoriesProvider).value;
    final results = widget.products.when(
      loading: () => Center(
        key: const Key('pos-products-loading'),
        child: Semantics(
          liveRegion: true,
          label: 'Loading products',
          child: const CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        key: const Key('pos-products-error'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Products could not be loaded. Your saved cart is still available.',
                textAlign: TextAlign.center,
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('retry-products-button'),
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
      data: (items) => items.isEmpty
          ? const Center(
              key: Key('pos-products-empty'),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No sellable products found. Check the branch price and default stock location.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _grid
          ? GridView.builder(
              shrinkWrap: !widget.fillHeight,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisExtent: 164,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _productCard(items[index]),
            )
          : ListView.separated(
              shrinkWrap: !widget.fillHeight,
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _productTile(items[index]),
            ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Products',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: _grid ? 'Show list' : 'Show grid',
                  onPressed: () => setState(() => _grid = !_grid),
                  icon: Icon(
                    _grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('pos-product-search'),
              controller: widget.searchController,
              focusNode: widget.focusNode,
              autofocus: true,
              onChanged: widget.onSearchChanged,
              onSubmitted: widget.onSubmitted,
              decoration: const InputDecoration(
                labelText: 'Scan barcode or search',
                hintText: 'Product name, SKU, or barcode · F2',
                prefixIcon: Icon(Icons.search),
                helperText: 'Search remains ready for barcode scanner input.',
              ),
            ),
            if (categories != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: const Text('All products'),
                        selected: widget.categoryId == null,
                        onSelected: (_) => widget.onCategoryChanged!(null),
                      ),
                    ),
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(category.name),
                          selected: widget.categoryId == category.id,
                          onSelected: (_) =>
                              widget.onCategoryChanged!(category.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (widget.fillHeight)
              Expanded(child: results)
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: results,
              ),
          ],
        ),
      ),
    );
  }

  bool _sellable(SaleProduct product) =>
      product.unitPriceMinor > 0 && product.availableQuantityMilli >= 1000;

  Widget _productTile(SaleProduct product) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${product.sku} · Stock ${Formatters.quantityMilli(product.availableQuantityMilli)} ${product.unitName}',
    ),
    onTap: _sellable(product) ? () => _add(product) : null,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Formatters.currencyMinor(product.unitPriceMinor),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          key: Key('add-product-${product.id}'),
          tooltip: _sellable(product)
              ? 'Add to cart'
              : 'Price or stock unavailable',
          onPressed: _sellable(product) ? () => _add(product) : null,
          icon: const Icon(Icons.add_shopping_cart_outlined),
        ),
      ],
    ),
  );

  Widget _productCard(SaleProduct product) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: Key('add-product-${product.id}'),
      onTap: _sellable(product) ? () => _add(product) : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(product.sku, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              Formatters.currencyMinor(product.unitPriceMinor),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Stock ${Formatters.quantityMilli(product.availableQuantityMilli)} ${product.unitName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );

  void _add(SaleProduct product) {
    final result = ref
        .read(cartControllerProvider.notifier)
        .addProduct(product);
    final failure = result.failureOrNull;
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
    widget.focusNode?.requestFocus();
  }
}
