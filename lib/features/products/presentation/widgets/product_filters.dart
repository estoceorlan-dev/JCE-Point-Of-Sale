import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/catalog_category.dart';

class ProductFilters extends StatelessWidget {
  const ProductFilters({
    super.key,
    required this.searchController,
    required this.categories,
    required this.categoryId,
    required this.includeArchived,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onIncludeArchivedChanged,
  });

  final TextEditingController searchController;
  final List<CatalogCategory> categories;
  final String? categoryId;
  final bool includeArchived;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<bool> onIncludeArchivedChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search products',
              hintText: 'Name, SKU, or barcode',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            initialValue: categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All categories'),
              ),
              ...categories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text(category.name),
                ),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
        ),
        FilterChip(
          selected: includeArchived,
          onSelected: onIncludeArchivedChanged,
          avatar: const Icon(Icons.archive_outlined, size: 18),
          label: const Text('Show archived'),
        ),
      ],
    );
  }
}
