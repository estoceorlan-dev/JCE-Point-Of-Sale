import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/sale.dart';
import '../providers/pos_providers.dart';

class ReceiptDialog extends ConsumerWidget {
  const ReceiptDialog({required this.sale, super.key});

  final SaleRecord sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(receiptRendererProvider).render(sale);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle_outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Sale ${sale.receiptNumber} completed')),
        ],
      ),
      content: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SingleChildScrollView(
          child: SelectableText(
            document.plainText,
            style: const TextStyle(fontFamily: 'monospace', height: 1.45),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
