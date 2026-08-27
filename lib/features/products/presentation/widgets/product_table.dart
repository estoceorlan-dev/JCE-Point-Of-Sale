import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/product_summary.dart';

class ProductTable extends StatelessWidget {
  const ProductTable({
    super.key,
    required this.products,
    required this.onView,
    required this.onEdit,
    required this.onArchiveToggle,
  });

  final List<ProductSummary> products;
  final ValueChanged<ProductSummary> onView;
  final ValueChanged<ProductSummary> onEdit;
  final ValueChanged<ProductSummary> onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyCatalog();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: products
                .map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ProductCard(
                      product: product,
                      onView: onView,
                      onEdit: onEdit,
                      onArchiveToggle: onArchiveToggle,
                    ),
                  ),
                )
                .toList(growable: false),
          );
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('SKU / Barcode')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Price'), numeric: true),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: products
                  .map(
                    (product) => DataRow(
                      onSelectChanged: (_) => onView(product),
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 180),
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            product.primaryBarcode == null
                                ? product.sku
                                : '${product.sku}\n${product.primaryBarcode}',
                          ),
                        ),
                        DataCell(Text(product.categoryName ?? 'Uncategorized')),
                        DataCell(
                          Text(
                            Formatters.currencyMinor(product.unitPriceMinor),
                          ),
                        ),
                        DataCell(_StatusBadge(isActive: product.isActive)),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => onEdit(product),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: product.isActive
                                    ? 'Archive'
                                    : 'Restore',
                                onPressed: () => onArchiveToggle(product),
                                icon: Icon(
                                  product.isActive
                                      ? Icons.archive_outlined
                                      : Icons.unarchive_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onView,
    required this.onEdit,
    required this.onArchiveToggle,
  });

  final ProductSummary product;
  final ValueChanged<ProductSummary> onView;
  final ValueChanged<ProductSummary> onEdit;
  final ValueChanged<ProductSummary> onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => onView(product),
        title: Text(product.name),
        subtitle: Text(
          '${product.sku} • ${product.categoryName ?? 'Uncategorized'}\n'
          '${Formatters.currencyMinor(product.unitPriceMinor)}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              onEdit(product);
            } else {
              onArchiveToggle(product);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'archive',
              child: Text(product.isActive ? 'Archive' : 'Restore'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.slate600;
    return Chip(
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.1),
      label: Text(
        isActive ? 'Active' : 'Archived',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No products found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text('Create a product or adjust the current filters.'),
            ],
          ),
        ),
      ),
    );
  }
}
