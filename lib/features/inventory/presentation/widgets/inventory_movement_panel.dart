import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/entities/inventory_transaction_type.dart';
import '../../domain/entities/stock_location.dart';
import '../controllers/inventory_mutation_controller.dart';
import '../providers/inventory_providers.dart';

class InventoryMovementPanel extends ConsumerStatefulWidget {
  const InventoryMovementPanel({super.key});

  @override
  ConsumerState<InventoryMovementPanel> createState() =>
      _InventoryMovementPanelState();
}

class _InventoryMovementPanelState
    extends ConsumerState<InventoryMovementPanel> {
  String? _stockLocationId;
  InventoryTransactionType? _type;

  @override
  Widget build(BuildContext context) {
    final filter = InventoryMovementFilter(
      stockLocationId: _stockLocationId,
      type: _type,
    );
    final movements = ref.watch(inventoryMovementsProvider(filter));
    final locations = ref.watch(stockLocationsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MovementFilters(
          locations: locations,
          stockLocationId: _stockLocationId,
          type: _type,
          onLocationChanged: (value) =>
              setState(() => _stockLocationId = value),
          onTypeChanged: (value) => setState(() => _type = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        movements.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text('Movement history could not be loaded: $error'),
            ),
          ),
          data: (items) => _MovementList(items: items),
        ),
      ],
    );
  }
}

class _MovementFilters extends StatelessWidget {
  const _MovementFilters({
    required this.locations,
    required this.stockLocationId,
    required this.type,
    required this.onLocationChanged,
    required this.onTypeChanged,
  });

  final List<StockLocation> locations;
  final String? stockLocationId;
  final InventoryTransactionType? type;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<InventoryTransactionType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: stockLocationId,
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
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<InventoryTransactionType?>(
            isExpanded: true,
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Movement type'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All movements')),
              for (final movementType in InventoryTransactionType.values)
                DropdownMenuItem(
                  value: movementType,
                  child: Text(movementType.label),
                ),
            ],
            onChanged: onTypeChanged,
          ),
        ),
      ],
    );
  }
}

class _MovementList extends ConsumerWidget {
  const _MovementList({required this.items});

  final List<InventoryMovement> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: Text('No inventory movements recorded yet.')),
        ),
      );
    }
    return Column(
      children: [
        for (final movement in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Card(
              child: ExpansionTile(
                leading: _MovementIcon(type: movement.type),
                title: Text(movement.type.label),
                subtitle: Text(
                  '${movement.occurredAt.toLocal()} • ${movement.reasonCode ?? 'No reason code'}',
                ),
                trailing:
                    movement.status == 'posted' &&
                        movement.type != InventoryTransactionType.reversal
                    ? IconButton(
                        tooltip: 'Reverse movement',
                        onPressed: () => _reverse(context, ref, movement),
                        icon: const Icon(Icons.undo),
                      )
                    : Chip(label: Text(movement.status)),
                children: [
                  for (final line in movement.lines)
                    ListTile(
                      title: Text('${line.sku} — ${line.productName}'),
                      subtitle: Text(line.stockLocationName),
                      trailing: Text(
                        '${line.quantityDeltaMilli > 0 ? '+' : ''}${Formatters.quantityMilli(line.quantityDeltaMilli)} → ${Formatters.quantityMilli(line.balanceAfterMilli)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: line.quantityDeltaMilli > 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ),
                  if (movement.notes != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Notes: ${movement.notes}'),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    InventoryMovement movement,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reverse inventory movement?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reversal reason',
            hintText: 'Explain why this movement is being reversed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Create reversal'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !context.mounted) return;
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .reverseMovement(transactionId: movement.id, reason: reason);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reversal posted.'))),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _MovementIcon extends StatelessWidget {
  const _MovementIcon({required this.type});

  final InventoryTransactionType type;

  @override
  Widget build(BuildContext context) {
    final incoming = switch (type) {
      InventoryTransactionType.openingBalance ||
      InventoryTransactionType.purchaseReceipt ||
      InventoryTransactionType.saleReturn ||
      InventoryTransactionType.adjustmentIncrease ||
      InventoryTransactionType.transferReceipt => true,
      _ => false,
    };
    return CircleAvatar(
      child: Icon(incoming ? Icons.south_west : Icons.north_east),
    );
  }
}
