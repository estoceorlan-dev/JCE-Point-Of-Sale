import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/sale.dart';
import '../controllers/discount_policy_controller.dart';

class DiscountPolicyDialog extends ConsumerStatefulWidget {
  const DiscountPolicyDialog({required this.policy, super.key});

  final DiscountPolicy policy;

  @override
  ConsumerState<DiscountPolicyDialog> createState() =>
      _DiscountPolicyDialogState();
}

class _DiscountPolicyDialogState extends ConsumerState<DiscountPolicyDialog> {
  late bool _enabled = widget.policy.approvalThresholdBasisPoints != null;
  late final TextEditingController _thresholdController = TextEditingController(
    text: widget.policy.approvalThresholdBasisPoints == null
        ? '10.00'
        : (widget.policy.approvalThresholdBasisPoints! / 100).toStringAsFixed(
            2,
          ),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Discount approval policy'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _enabled = value),
              title: const Text('Require manager approval'),
              subtitle: const Text(
                'Discounts above the configured percentage need an authorized user.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _thresholdController,
              enabled: _enabled && !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Approval threshold',
                suffixText: '%',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    int? threshold;
    if (_enabled) {
      threshold = Formatters.parseCurrencyMinor(_thresholdController.text);
      if (threshold == null || threshold < 0 || threshold > 10000) {
        setState(() => _error = 'Enter a percentage from 0 to 100.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(discountPolicyControllerProvider.notifier)
        .save(DiscountPolicy(approvalThresholdBasisPoints: threshold));
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
    );
  }
}
