import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/cash_shift.dart';
import '../controllers/shift_mutation_controller.dart';

class ShiftPolicyDialog extends ConsumerStatefulWidget {
  const ShiftPolicyDialog({super.key, required this.policy});

  final ShiftPolicy policy;

  @override
  ConsumerState<ShiftPolicyDialog> createState() => _ShiftPolicyDialogState();
}

class _ShiftPolicyDialogState extends ConsumerState<ShiftPolicyDialog> {
  late bool _allowMultiple;
  late bool _allowSalesWithoutShift;
  late final TextEditingController _thresholdController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _allowMultiple = widget.policy.allowMultipleOpenShiftsPerUser;
    _allowSalesWithoutShift = widget.policy.allowSalesWithoutOpenShift;
    final threshold = widget.policy.cashDiscrepancyApprovalThresholdMinor;
    _thresholdController = TextEditingController(
      text: threshold == null ? '' : _minorInput(threshold),
    );
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(shiftMutationControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('Register and shift policy'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow one user to hold multiple open shifts'),
              subtitle: const Text(
                'Each register still permits only one open shift.',
              ),
              value: _allowMultiple,
              onChanged: saving
                  ? null
                  : (value) => setState(() => _allowMultiple = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow sales without an open shift'),
              subtitle: const Text(
                'Keep disabled for controlled cash operations.',
              ),
              value: _allowSalesWithoutShift,
              onChanged: saving
                  ? null
                  : (value) => setState(() => _allowSalesWithoutShift = value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _thresholdController,
              decoration: const InputDecoration(
                labelText: 'Cash discrepancy approval threshold',
                prefixText: 'PHP ',
                helperText:
                    'Leave blank when manager approval is not threshold-based.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Saving…' : 'Save policy'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final raw = _thresholdController.text.trim();
    final threshold = raw.isEmpty ? null : Formatters.parseCurrencyMinor(raw);
    if (raw.isNotEmpty && (threshold == null || threshold < 0)) {
      setState(() => _error = 'Enter a non-negative threshold.');
      return;
    }
    setState(() => _error = null);
    final result = await ref
        .read(shiftMutationControllerProvider.notifier)
        .configurePolicy(
          ShiftPolicy(
            allowMultipleOpenShiftsPerUser: _allowMultiple,
            allowSalesWithoutOpenShift: _allowSalesWithoutShift,
            cashDiscrepancyApprovalThresholdMinor: threshold,
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}

String _minorInput(int minor) {
  final whole = minor ~/ 100;
  final fraction = (minor.abs() % 100).toString().padLeft(2, '0');
  return '$whole.$fraction';
}
