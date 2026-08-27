import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/inventory_balance.dart';
import '../../domain/entities/stock_location.dart';
import '../providers/inventory_providers.dart';
import 'reorder_point_dialog.dart';

class InventoryBalancePanel extends ConsumerStatefulWidget {
  const InventoryBalancePanel({super.key});

  @override
  ConsumerState<InventoryBalancePanel> createState() =>
      _InventoryBalancePanelState();
}

class _InventoryBalancePanelState extends ConsumerState<InventoryBalancePanel> {
  final _searchController = TextEditingController();
  String? _locationId;
  bool _lowStockOnly = false;
  Timer? _debounce;
  String _search = '';

  InventoryBalanceQuery get _query => InventoryBalanceQuery(
    search: _search,
    stockLocationId: _locationId,
    lowStockOnly: _lowStockOnly,
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(inventoryBalancesProvider(_query));
    final locations = ref.watch(stockLocationsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Filters(
          searchController: _searchController,
          locations: locations,
          locationId: _locationId,
          lowStockOnly: _lowStockOnly,
          onSearchChanged: _searchChanged,
          onLocationChanged: (value) => setState(() => _locationId = value),
          onLowStockChanged: (value) => setState(() => _lowStockOnly = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        balances.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => _ErrorCard(error: error),
          data: (items) => Column(
            children: [
              _BalanceMetrics(items: items),
              const SizedBox(height: AppSpacing.lg),
              _BalanceTable(items: items, onSetReorderPoint: _setReorderPoint),
            ],
          ),
        ),
      ],
    );
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _search = value);
    });
  }

  Future<void> _setReorderPoint(InventoryBalance balance) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => ReorderPointDialog(balance: balance),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.locations,
    required this.locationId,
    required this.lowStockOnly,
    required this.onSearchChanged,
    required this.onLocationChanged,
    required this.onLowStockChanged,
  });

  final TextEditingController searchController;
  final List<StockLocation> locations;
  final String? locationId;
  final bool lowStockOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<bool> onLowStockChanged;

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
              prefixIcon: Icon(Icons.search),
              hintText: 'Search product or SKU',
            ),
          ),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: locationId,
            decoration: const InputDecoration(labelText: 'Stock location'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All locations')),
              for (final location in locations)
                DropdownMenuItem(
                  value: location.id,
                  child: Text(location.name),
                ),
            ],
            onChanged: onLocationChanged,
          ),
        ),
        FilterChip(
          label: const Text('Low stock only'),
          selected: lowStockOnly,
          onSelected: onLowStockChanged,
        ),
      ],
    );
  }
}

class _BalanceMetrics extends StatelessWidget {
  const _BalanceMetrics({required this.items});

  final List<InventoryBalance> items;

  @override
  Widget build(BuildContext context) {
    final lowStock = items.where((item) => item.isLowStock).length;
    final onHand = items.fold<int>(
      0,
      (total, item) => total + item.onHandMilli,
    );
    return Row(
      children: [
        Expanded(
          child: _Metric(label: 'Balance records', value: '${items.length}'),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Metric(
            label: 'Low-stock records',
            value: '$lowStock',
            warning: lowStock > 0,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Metric(
            label: 'Total on hand',
            value: Formatters.quantityMilli(onHand),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: warning ? AppColors.warning : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceTable extends StatelessWidget {
  const _BalanceTable({required this.items, required this.onSetReorderPoint});

  final List<InventoryBalance> items;
  final ValueChanged<InventoryBalance> onSetReorderPoint;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: Text(
              'No balance records yet. Post an opening balance or adjustment to begin.',
            ),
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('Location')),
            DataColumn(numeric: true, label: Text('On hand')),
            DataColumn(numeric: true, label: Text('Reserved')),
            DataColumn(numeric: true, label: Text('Available')),
            DataColumn(numeric: true, label: Text('Reorder point')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final item in items)
              DataRow(
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(item.productName), Text(item.sku)],
                    ),
                  ),
                  DataCell(Text(item.stockLocationName)),
                  DataCell(Text(Formatters.quantityMilli(item.onHandMilli))),
                  DataCell(Text(Formatters.quantityMilli(item.reservedMilli))),
                  DataCell(Text(Formatters.quantityMilli(item.availableMilli))),
                  DataCell(
                    Text(Formatters.quantityMilli(item.reorderPointMilli)),
                  ),
                  DataCell(
                    Chip(
                      label: Text(item.isLowStock ? 'Low stock' : 'Healthy'),
                      avatar: Icon(
                        item.isLowStock
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 18,
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      tooltip: 'Set reorder point',
                      onPressed: () => onSetReorderPoint(item),
                      icon: const Icon(Icons.edit_notifications_outlined),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text('Inventory balances could not be loaded: $error'),
      ),
    );
  }
}
