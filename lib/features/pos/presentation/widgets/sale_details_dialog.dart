import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/sale.dart';
import 'receipt_dialog.dart';

class SaleDetailsDialog extends StatelessWidget {
  const SaleDetailsDialog({required this.sale, super.key});

  final SaleRecord sale;

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ),
      ),
      actions: [
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
