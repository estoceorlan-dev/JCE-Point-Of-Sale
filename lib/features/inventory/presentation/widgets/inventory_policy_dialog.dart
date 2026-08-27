import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/inventory_adjustment.dart';
import '../controllers/inventory_mutation_controller.dart';

class InventoryPolicyDialog extends ConsumerStatefulWidget {
  const InventoryPolicyDialog({super.key, required this.policy});

  final InventoryPolicy policy;

  @override
  ConsumerState<InventoryPolicyDialog> createState() =>
      _InventoryPolicyDialogState();
}

class _InventoryPolicyDialogState extends ConsumerState<InventoryPolicyDialog> {
  late bool _allowNegativeStock = widget.policy.allowNegativeStock;
  late final TextEditingController _thresholdController = TextEditingController(
    text: widget.policy.adjustmentApprovalThresholdMilli == null
        ? ''
        : Formatters.quantityMilli(
            widget.policy.adjustmentApprovalThresholdMilli!,
          ),
  );
  String? _error;

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(inventoryMutationControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('Branch inventory policy'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow negative stock'),
              subtitle: const Text(
                'When disabled, outgoing movements stop at zero on hand.',
              ),
              value: _allowNegativeStock,
              onChanged: saving
                  ? null
                  : (value) => setState(() => _allowNegativeStock = value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _thresholdController,
              decoration: const InputDecoration(
                labelText: 'Manager approval threshold',
                helperText: 'Leave empty to disable the threshold.',
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
    final thresholdText = _thresholdController.text.trim();
    final threshold = thresholdText.isEmpty
        ? null
        : Formatters.parseQuantityMilli(thresholdText);
    if (thresholdText.isNotEmpty && (threshold == null || threshold < 0)) {
      setState(() => _error = 'Enter a valid non-negative threshold.');
      return;
    }
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .configurePolicy(
          InventoryPolicy(
            allowNegativeStock: _allowNegativeStock,
            adjustmentApprovalThresholdMilli: threshold,
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
