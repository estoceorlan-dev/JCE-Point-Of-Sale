import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/sale_correction.dart';
import '../providers/pos_providers.dart';

class CorrectionPolicyDialog extends ConsumerStatefulWidget {
  const CorrectionPolicyDialog({super.key});

  @override
  ConsumerState<CorrectionPolicyDialog> createState() =>
      _CorrectionPolicyDialogState();
}

class _CorrectionPolicyDialogState
    extends ConsumerState<CorrectionPolicyDialog> {
  final _thresholdController = TextEditingController();
  final _voidWindowController = TextEditingController(text: '15');
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _thresholdController.dispose();
    _voidWindowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policy = ref.watch(correctionPolicyProvider);
    final current = policy.valueOrNull;
    if (!_initialized && current != null) {
      _initialized = true;
      _thresholdController.text = current.returnApprovalThresholdMinor == null
          ? ''
          : (current.returnApprovalThresholdMinor! / 100).toStringAsFixed(2);
      _voidWindowController.text = current.voidWindowMinutes.toString();
    }
    return AlertDialog(
      title: const Text('Return and void policy'),
      content: SizedBox(
        width: 480,
        child: policy.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Policy could not be loaded: $error'),
          data: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _thresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Manager approval threshold',
                  helperText: 'Leave blank to disable amount-based approval.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _voidWindowController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cashier void window (minutes)',
                  helperText:
                      'Voids after this window require manager approval.',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
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
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save policy'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final thresholdText = _thresholdController.text.trim();
    final threshold = thresholdText.isEmpty
        ? null
        : Formatters.parseCurrencyMinor(thresholdText);
    final voidWindow = int.tryParse(_voidWindowController.text.trim());
    if ((thresholdText.isNotEmpty && threshold == null) ||
        (threshold != null && threshold < 0) ||
        voidWindow == null ||
        voidWindow < 0) {
      setState(() => _error = 'Enter a valid threshold and void window.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(configureCorrectionPolicyUseCaseProvider)(
      session: ref.read(activePosSessionProvider),
      policy: SaleCorrectionPolicy(
        returnApprovalThresholdMinor: threshold,
        voidWindowMinutes: voidWindow,
      ),
    );
    if (!mounted) return;
    if (result.isFailure) {
      setState(() {
        _saving = false;
        _error = result.failureOrNull!.message;
      });
      return;
    }
    ref.invalidate(correctionPolicyProvider);
    Navigator.pop(context);
  }
}
