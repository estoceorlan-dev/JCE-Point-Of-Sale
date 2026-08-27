import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../products/domain/entities/product_query.dart';
import '../../../products/presentation/providers/products_providers.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_location.dart';
import '../controllers/inventory_mutation_controller.dart';
import '../providers/inventory_providers.dart';

class StartStockCountDialog extends ConsumerStatefulWidget {
  const StartStockCountDialog({super.key});

  @override
  ConsumerState<StartStockCountDialog> createState() =>
      _StartStockCountDialogState();
}

class _StartStockCountDialogState extends ConsumerState<StartStockCountDialog> {
  static const _productQuery = ProductQuery(pageSize: 250);

  final _notesController = TextEditingController();
  final _selectedProductIds = <String>{};
  String? _locationId;
  StockCountType _type = StockCountType.full;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(stockLocationsProvider).value ?? const [];
    final products =
        ref.watch(productPageProvider(_productQuery)).value?.items ?? const [];
    final saving = ref.watch(inventoryMutationControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('Start stock count'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _locationId,
                decoration: const InputDecoration(labelText: 'Stock location'),
                items: _locationItems(locations),
                onChanged: saving
                    ? null
                    : (value) => setState(() => _locationId = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<StockCountType>(
                segments: const [
                  ButtonSegment(
                    value: StockCountType.full,
                    label: Text('Full count'),
                  ),
                  ButtonSegment(
                    value: StockCountType.cycle,
                    label: Text('Cycle count'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: saving
                    ? null
                    : (value) => setState(() => _type = value.single),
              ),
              if (_type == StockCountType.cycle) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Products to count',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final product in products)
                        CheckboxListTile(
                          dense: true,
                          title: Text(product.name),
                          subtitle: Text(product.sku),
                          value: _selectedProductIds.contains(product.id),
                          onChanged: saving
                              ? null
                              : (selected) => setState(() {
                                  if (selected ?? false) {
                                    _selectedProductIds.add(product.id);
                                  } else {
                                    _selectedProductIds.remove(product.id);
                                  }
                                }),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Inventory movements at this location are frozen until the count is completed or cancelled.',
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _start,
          child: Text(saving ? 'Starting…' : 'Start count'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _locationItems(List<StockLocation> locations) {
    return [
      for (final location in locations.where((item) => item.isActive))
        DropdownMenuItem(value: location.id, child: Text(location.name)),
    ];
  }

  Future<void> _start() async {
    if (_locationId == null) {
      setState(() => _error = 'Select a stock location.');
      return;
    }
    if (_type == StockCountType.cycle && _selectedProductIds.isEmpty) {
      setState(() => _error = 'Select at least one product for a cycle count.');
      return;
    }
    setState(() => _error = null);
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .startCount(
          StartStockCountDraft(
            stockLocationId: _locationId!,
            type: _type,
            productIds: _selectedProductIds.toList(growable: false),
            notes: _notesController.text,
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
