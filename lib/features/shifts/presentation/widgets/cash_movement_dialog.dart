import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/cash_movement.dart';
import '../controllers/shift_mutation_controller.dart';

class CashMovementDialog extends ConsumerStatefulWidget {
  const CashMovementDialog({super.key, required this.shiftId});

  final String shiftId;

  @override
  ConsumerState<CashMovementDialog> createState() => _CashMovementDialogState();
}

class _CashMovementDialogState extends ConsumerState<CashMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  CashMovementType _type = CashMovementType.cashIn;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(shiftMutationControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('Drawer movement'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CashMovementType>(
                isExpanded: true,
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Movement type'),
                items: [
                  for (final type in CashMovementType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'PHP ',
                  helperText: _type == CashMovementType.correction
                      ? 'Use a negative value to reduce expected cash.'
                      : 'Enter a positive amount.',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (value) {
                  final minor = Formatters.parseCurrencyMinor(value ?? '');
                  if (minor == null || minor == 0) {
                    return 'Enter a non-zero amount.';
                  }
                  if (_type != CashMovementType.correction && minor < 0) {
                    return 'Enter a positive amount for this movement.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator: (value) =>
                    (value?.trim().length ?? 0) < 2 ? 'Enter a reason.' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _post,
          child: Text(saving ? 'Posting…' : 'Post movement'),
        ),
      ],
    );
  }

  Future<void> _post() async {
    if (!_formKey.currentState!.validate()) return;
    var amount = Formatters.parseCurrencyMinor(_amountController.text)!;
    if (_type == CashMovementType.cashOut || _type == CashMovementType.payout) {
      amount = -amount.abs();
    } else if (_type == CashMovementType.cashIn) {
      amount = amount.abs();
    }
    setState(() => _error = null);
    final result = await ref
        .read(shiftMutationControllerProvider.notifier)
        .postMovement(
          CashMovementDraft(
            shiftId: widget.shiftId,
            type: _type,
            amountMinor: amount,
            reason: _reasonController.text,
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
