import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_correction.dart';
import '../providers/pos_providers.dart';

class CorrectionReceiptDialog extends ConsumerWidget {
  const CorrectionReceiptDialog({
    required this.sale,
    required this.correction,
    super.key,
  });

  final SaleRecord sale;
  final SaleCorrectionRecord correction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref
        .watch(correctionReceiptRendererProvider)
        .render(sale: sale, correction: correction);
    return AlertDialog(
      title: Text('${correction.type.label} ${correction.returnNumber}'),
      content: Container(
        width: 440,
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
