import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/stock_count.dart';
import '../controllers/inventory_mutation_controller.dart';
import '../providers/inventory_providers.dart';
import 'record_stock_count_dialog.dart';

class StockCountPanel extends ConsumerWidget {
  const StockCountPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(stockCountsProvider);
    return counts.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Stock counts could not be loaded: $error'),
        ),
      ),
      data: (items) => _CountList(items: items),
    );
  }
}

class _CountList extends ConsumerWidget {
  const _CountList({required this.items});

  final List<StockCount> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: Text('No stock counts have been started.')),
        ),
      );
    }
    return Column(
      children: [
        for (final count in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Card(
              child: ExpansionTile(
                initiallyExpanded: count.status == StockCountStatus.inProgress,
                leading: const CircleAvatar(
                  child: Icon(Icons.fact_check_outlined),
                ),
                title: Text('${count.type.label} — ${count.stockLocationName}'),
                subtitle: Text(
                  '${count.status.label} • ${count.items.length} products',
                ),
                children: [
                  for (final item in count.items)
                    ListTile(
                      title: Text('${item.sku} — ${item.productName}'),
                      subtitle: Text(
                        'Expected ${Formatters.quantityMilli(item.expectedQuantityMilli)}',
                      ),
                      trailing: count.status == StockCountStatus.inProgress
                          ? TextButton(
                              onPressed: () => showDialog<bool>(
                                context: context,
                                builder: (context) => RecordStockCountDialog(
                                  count: count,
                                  item: item,
                                ),
                              ),
                              child: Text(
                                item.countedQuantityMilli == null
                                    ? 'Record'
                                    : Formatters.quantityMilli(
                                        item.countedQuantityMilli!,
                                      ),
                              ),
                            )
                          : _Variance(item: item),
                    ),
                  if (count.status == StockCountStatus.inProgress)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Wrap(
                        spacing: AppSpacing.md,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _cancel(context, ref, count),
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel count'),
                          ),
                          FilledButton.icon(
                            onPressed: count.hasUncountedItems
                                ? null
                                : () => _complete(context, ref, count),
                            icon: const Icon(Icons.check),
                            label: const Text('Complete count'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    StockCount count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const AppConfirmationDialog(
        title: 'Complete stock count?',
        message:
            'Variance entries will be posted to the immutable inventory ledger.',
        confirmLabel: 'Complete',
        icon: Icons.fact_check_outlined,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .completeCount(count);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (correctionId) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            correctionId == null
                ? 'Count completed with no variance.'
                : 'Count completed and variance correction posted.',
          ),
        ),
      ),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    StockCount count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const AppConfirmationDialog(
        title: 'Cancel stock count?',
        message:
            'Recorded quantities will remain in history, but no correction will be posted.',
        confirmLabel: 'Cancel count',
        destructive: true,
        icon: Icons.cancel_outlined,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .cancelCount(count);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock count cancelled.'))),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _Variance extends StatelessWidget {
  const _Variance({required this.item});

  final StockCountItem item;

  @override
  Widget build(BuildContext context) {
    final variance = item.varianceQuantityMilli ?? 0;
    return Text(
      '${variance > 0 ? '+' : ''}${Formatters.quantityMilli(variance)}',
      style: TextStyle(
        color: variance == 0
            ? null
            : variance > 0
            ? AppColors.success
            : AppColors.danger,
      ),
    );
  }
}
