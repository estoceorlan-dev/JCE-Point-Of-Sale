import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/cash_shift.dart';

class ActiveShiftPanel extends StatelessWidget {
  const ActiveShiftPanel({
    super.key,
    required this.shift,
    required this.isCurrentUser,
    required this.onCashMovement,
    required this.onClose,
  });

  final CashShift shift;
  final bool isCurrentUser;
  final VoidCallback onCashMovement;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_open_outlined, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Active shift • ${shift.registerName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(shift.status.label)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                _AmountMetric(
                  label: 'Opening cash',
                  value: shift.openingCashMinor,
                ),
                _AmountMetric(
                  label: 'Drawer movements',
                  value: shift.cashMovementTotalMinor,
                ),
                _AmountMetric(label: 'Cash sales', value: shift.cashSalesMinor),
                _AmountMetric(
                  label: 'Expected cash',
                  value: shift.expectedCashMinor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Opened ${shift.openedAt.toLocal()} • Device ${shift.deviceId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!isCurrentUser) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'This shift belongs to another user. Manager approval is required to close it.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                OutlinedButton.icon(
                  onPressed: isCurrentUser ? onCashMovement : null,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Drawer movement'),
                ),
                FilledButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Close shift'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Cash movement history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (shift.movements.isEmpty)
              const Text('No drawer movements have been posted.')
            else
              for (final movement in shift.movements.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    movement.amountMinor > 0
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                    color: movement.amountMinor > 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                  title: Text('${movement.type.label} • ${movement.reason}'),
                  subtitle: Text(movement.occurredAt.toLocal().toString()),
                  trailing: Text(
                    Formatters.currencyMinor(movement.amountMinor),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Formatters.currencyMinor(value),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
