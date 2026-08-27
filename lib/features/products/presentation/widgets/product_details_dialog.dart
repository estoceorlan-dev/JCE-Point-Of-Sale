import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/product_summary.dart';
import '../providers/products_providers.dart';

class ProductDetailsDialog extends ConsumerWidget {
  const ProductDetailsDialog({super.key, required this.summary});

  final ProductSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailsProvider(summary.id));
    return AlertDialog(
      title: Text(summary.name),
      content: SizedBox(
        width: 520,
        child: product.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load product: $error'),
          data: (details) {
            if (details == null) {
              return const Text('This product is no longer available.');
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Detail(label: 'SKU', value: details.sku),
                  _Detail(
                    label: 'Price',
                    value: Formatters.currencyMinor(summary.unitPriceMinor),
                  ),
                  _Detail(
                    label: 'Price scope',
                    value: details.activePrice?.scope.name ?? 'Not priced',
                  ),
                  _Detail(label: 'Unit', value: summary.unitName),
                  _Detail(
                    label: 'Category',
                    value: summary.categoryName ?? 'Uncategorized',
                  ),
                  _Detail(
                    label: 'Status',
                    value: details.isActive ? 'Active' : 'Archived',
                  ),
                  _Detail(
                    label: 'Tax category',
                    value: details.taxCategoryId ?? 'None',
                  ),
                  _Detail(
                    label: 'Barcodes',
                    value: details.barcodes.isEmpty
                        ? 'None'
                        : details.barcodes.join(', '),
                  ),
                  if (details.description != null)
                    _Detail(label: 'Description', value: details.description!),
                  if (details.imagePaths.isNotEmpty)
                    _Detail(
                      label: 'Queued images',
                      value: details.imagePaths.join('\n'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(value),
        ],
      ),
    );
  }
}
