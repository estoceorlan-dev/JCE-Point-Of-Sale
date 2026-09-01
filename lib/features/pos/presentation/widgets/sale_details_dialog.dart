import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/models/permission.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_correction.dart';
import '../../domain/entities/sale_status.dart';
import '../providers/pos_providers.dart';
import 'correction_receipt_dialog.dart';
import 'receipt_dialog.dart';
import 'sale_correction_dialog.dart';

class SaleDetailsDialog extends ConsumerWidget {
  const SaleDetailsDialog({required this.sale, super.key});

  final SaleRecord sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCorrect =
        ref
            .watch(activePosSessionProvider)
            ?.can(AppPermission.processSaleReturns) ??
        false;
    final hasReturnableItems = sale.items.any(
      (item) => item.returnableQuantityMilli > 0,
    );
    return AlertDialog(
      title: Text('Receipt ${sale.receiptNumber}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  Chip(label: Text(sale.status.label)),
                  Chip(label: Text(sale.registerName)),
                  if (sale.customerDisplayName case final customer?)
                    Chip(
                      avatar: const Icon(Icons.person_outline, size: 18),
                      label: Text(customer),
                    ),
                  Chip(label: Text(sale.completedAt.toLocal().toString())),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final item in sale.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text(
                    '${item.sku} · ${Formatters.quantityMilli(item.quantityMilli)} ${item.unitName} × ${Formatters.currencyMinor(item.unitPriceMinor)}',
                  ),
                  trailing: Text(
                    Formatters.currencyMinor(item.totalAmountMinor),
                  ),
                ),
              const Divider(),
              _DetailAmount(label: 'Subtotal', amount: sale.subtotalMinor),
              if (sale.discountMinor > 0)
                _DetailAmount(label: 'Discount', amount: -sale.discountMinor),
              _DetailAmount(label: 'Tax', amount: sale.taxMinor),
              _DetailAmount(label: 'Total', amount: sale.totalMinor),
              const SizedBox(height: AppSpacing.md),
              for (final payment in sale.payments)
                _DetailAmount(
                  label: payment.method.label,
                  amount: payment.tenderedAmountMinor,
                ),
              _DetailAmount(label: 'Change', amount: sale.changeMinor),
              if (sale.corrections.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Corrections',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final correction in sale.corrections)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      correction.type == SaleCorrectionType.voidSale
                          ? Icons.block_outlined
                          : Icons.assignment_return_outlined,
                    ),
                    title: Text(correction.returnNumber),
                    subtitle: Text(
                      '${correction.type.label} · ${correction.status} · ${correction.reasonCode} · ${correction.completedAt.toLocal()}',
                    ),
                    trailing: TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => CorrectionReceiptDialog(
                          sale: sale,
                          correction: correction,
                        ),
                      ),
                      child: Text(
                        Formatters.currencyMinor(correction.totalMinor),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (canCorrect &&
            hasReturnableItems &&
            (sale.status == SaleStatus.completed ||
                sale.status == SaleStatus.partiallyReturned))
          TextButton.icon(
            onPressed: () => _correct(context, SaleCorrectionType.saleReturn),
            icon: const Icon(Icons.assignment_return_outlined),
            label: const Text('Return'),
          ),
        if (canCorrect &&
            sale.status == SaleStatus.completed &&
            sale.corrections.isEmpty)
          TextButton.icon(
            onPressed: () => _correct(context, SaleCorrectionType.voidSale),
            icon: const Icon(Icons.block_outlined),
            label: const Text('Void'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            showDialog<void>(
              context: context,
              builder: (context) => ReceiptDialog(sale: sale),
            );
          },
          icon: const Icon(Icons.receipt_outlined),
          label: const Text('View receipt'),
        ),
      ],
    );
  }

  Future<void> _correct(BuildContext context, SaleCorrectionType type) async {
    final result = await showDialog<SaleCorrectionResult>(
      context: context,
      builder: (context) => SaleCorrectionDialog(sale: sale, type: type),
    );
    if (result == null || !context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${type.label} ${result.returnNumber} saved.')),
    );
  }
}

class _DetailAmount extends StatelessWidget {
  const _DetailAmount({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(Formatters.currencyMinor(amount)),
        ],
      ),
    );
  }
}
