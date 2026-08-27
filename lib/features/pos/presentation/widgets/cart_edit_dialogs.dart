import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';

class QuantityDialog extends StatefulWidget {
  const QuantityDialog({required this.quantityMilli, super.key});

  final int quantityMilli;

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: Formatters.quantityMilli(widget.quantityMilli),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change quantity'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Quantity', errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }

  void _save() {
    final value = Formatters.parseQuantityMilli(_controller.text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a quantity greater than zero.');
      return;
    }
    Navigator.pop(context, value);
  }
}

class DiscountDialog extends StatefulWidget {
  const DiscountDialog({
    required this.title,
    required this.currentAmountMinor,
    required this.currentReason,
    super.key,
  });

  final String title;
  final int currentAmountMinor;
  final String? currentReason;

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.currentAmountMinor == 0
        ? ''
        : (widget.currentAmountMinor / 100).toStringAsFixed(2),
  );
  late final TextEditingController _reasonController = TextEditingController(
    text: widget.currentReason ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Discount amount',
                prefixText: 'PHP ',
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.currentAmountMinor > 0)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const DiscountInput(amountMinor: 0, reason: ''),
            ),
            child: const Text('Remove discount'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }

  void _save() {
    final amount = Formatters.parseCurrencyMinor(_amountController.text);
    final reason = _reasonController.text.trim();
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'A discount reason is required.');
      return;
    }
    Navigator.pop(context, DiscountInput(amountMinor: amount, reason: reason));
  }
}

class DiscountInput {
  const DiscountInput({required this.amountMinor, required this.reason});

  final int amountMinor;
  final String reason;
}
