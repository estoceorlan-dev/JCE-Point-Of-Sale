import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/error/result.dart';
import '../../data/services/receipt_pdf_saver.dart';
import '../../domain/entities/sale.dart';
import '../../domain/services/receipt_pdf_generator.dart';
import '../providers/pos_providers.dart';

class ReceiptDialog extends ConsumerStatefulWidget {
  const ReceiptDialog({required this.sale, super.key});

  final SaleRecord sale;

  @override
  ConsumerState<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends ConsumerState<ReceiptDialog> {
  bool _working = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
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
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(_message!),
          ),
        TextButton.icon(
          onPressed: _working ? null : _savePdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Save PDF'),
        ),
        OutlinedButton.icon(
          onPressed: _working ? null : _reprint,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Reprint'),
        ),
        FilledButton(
          onPressed: _working ? null : () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Future<void> _reprint() async {
    setState(() {
      _working = true;
      _message = null;
    });
    final result = await ref.read(deliverSaleReceiptUseCaseProvider)(
      session: ref.read(activePosSessionProvider),
      sale: widget.sale,
      isReprint: true,
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      _message = switch (result) {
        FailureResult(:final failure) => failure.message,
        SuccessResult(:final value) when value.printed =>
          'Reprint sent to the printer and recorded in the audit trail.',
        SuccessResult(:final value) when value.queuedForRetry =>
          'Printer unavailable. The audited reprint is queued for retry.',
        SuccessResult(:final value) =>
          value.message ?? 'Use the screen or PDF receipt fallback.',
      };
    });
  }

  Future<void> _savePdf() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final text = ref
          .read(receiptRendererProvider)
          .render(widget.sale)
          .plainText;
      final bytes = ReceiptPdfGenerator.generate(text);
      final safeNumber = widget.sale.receiptNumber.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final location = await saveReceiptPdf(bytes, 'receipt_$safeNumber.pdf');
      if (mounted) {
        setState(() => _message = 'PDF receipt saved to $location.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'PDF receipt could not be saved: $error');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
