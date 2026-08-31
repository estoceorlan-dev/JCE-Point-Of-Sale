import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/stock_transfer.dart';
import '../controllers/transfer_mutation_controller.dart';

class TransferPolicyDialog extends ConsumerStatefulWidget {
  const TransferPolicyDialog({super.key, required this.policy});

  final TransferPolicy policy;

  @override
  ConsumerState<TransferPolicyDialog> createState() =>
      _TransferPolicyDialogState();
}

class _TransferPolicyDialogState extends ConsumerState<TransferPolicyDialog> {
  late final TextEditingController _thresholdController;
  late bool _requiresApproval;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requiresApproval = widget.policy.approvalThresholdMilli != null;
    _thresholdController = TextEditingController(
      text: widget.policy.approvalThresholdMilli == null
          ? ''
          : Formatters.quantityMilli(widget.policy.approvalThresholdMilli!),
    );
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(transferMutationControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('Transfer approval policy'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require approval above a quantity'),
              subtitle: const Text(
                'Transfers at or below the threshold are approved automatically on submission.',
              ),
              value: _requiresApproval,
              onChanged: saving
                  ? null
                  : (value) => setState(() => _requiresApproval = value),
            ),
            if (_requiresApproval)
              TextField(
                controller: _thresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quantity threshold',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
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
    final threshold = _requiresApproval
        ? Formatters.parseQuantityMilli(_thresholdController.text)
        : null;
    if (_requiresApproval && (threshold == null || threshold < 0)) {
      setState(() => _error = 'Enter a valid non-negative threshold.');
      return;
    }
    final result = await ref
        .read(transferMutationControllerProvider.notifier)
        .configurePolicy(TransferPolicy(approvalThresholdMilli: threshold));
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
