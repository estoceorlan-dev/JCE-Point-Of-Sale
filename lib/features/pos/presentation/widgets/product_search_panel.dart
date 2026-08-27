import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/sale_product.dart';
import '../controllers/cart_controller.dart';

class ProductSearchPanel extends ConsumerWidget {
  const ProductSearchPanel({
    required this.searchController,
    required this.products,
    required this.onSearchChanged,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController searchController;
  final AsyncValue<List<SaleProduct>> products;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Products', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('pos-product-search'),
              controller: searchController,
              autofocus: true,
              onChanged: onSearchChanged,
              onSubmitted: onSubmitted,
              decoration: const InputDecoration(
                labelText: 'Scan barcode or search',
                hintText: 'Product name, SKU, or barcode',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            products.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text('Products could not be loaded: $error'),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No sellable products found. Check the branch price and default stock location.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 560),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = items[index];
                          final sellable =
                              product.unitPriceMinor > 0 &&
                              product.availableQuantityMilli >= 1000;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(product.name),
                            subtitle: Text(
                              '${product.sku} · Stock ${Formatters.quantityMilli(product.availableQuantityMilli)} ${product.unitName}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Formatters.currencyMinor(
                                    product.unitPriceMinor,
                                  ),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                IconButton.filledTonal(
                                  key: Key('add-product-${product.id}'),
                                  tooltip: sellable
                                      ? 'Add to cart'
                                      : 'Price or stock unavailable',
                                  onPressed: sellable
                                      ? () => _add(context, ref, product)
                                      : null,
                                  icon: const Icon(
                                    Icons.add_shopping_cart_outlined,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _add(BuildContext context, WidgetRef ref, SaleProduct product) {
    final result = ref
        .read(cartControllerProvider.notifier)
        .addProduct(product);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}
