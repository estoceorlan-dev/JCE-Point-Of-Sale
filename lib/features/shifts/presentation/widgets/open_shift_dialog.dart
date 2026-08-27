import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/cash_shift.dart';
import '../../domain/entities/register.dart';
import '../controllers/shift_mutation_controller.dart';

class OpenShiftDialog extends ConsumerStatefulWidget {
  const OpenShiftDialog({
    super.key,
    required this.deviceId,
    required this.registers,
  });

  final String deviceId;
  final List<Register> registers;

  @override
  ConsumerState<OpenShiftDialog> createState() => _OpenShiftDialogState();
}

class _OpenShiftDialogState extends ConsumerState<OpenShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _openingController = TextEditingController(text: '0.00');
  final _notesController = TextEditingController();
  String? _registerId;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.registers.length == 1) {
      _registerId = widget.registers.single.id;
    }
  }

  @override
  void dispose() {
    _openingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(shiftMutationControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('Open shift'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _registerId,
                decoration: const InputDecoration(labelText: 'Register'),
                items: [
                  for (final register in widget.registers)
                    DropdownMenuItem(
                      value: register.id,
                      child: Text('${register.code} — ${register.name}'),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => _registerId = value),
                validator: (value) =>
                    value == null ? 'Select a register.' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _openingController,
                decoration: const InputDecoration(
                  labelText: 'Opening cash',
                  prefixText: 'PHP ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final minor = Formatters.parseCurrencyMinor(value ?? '');
                  return minor == null || minor < 0
                      ? 'Enter a non-negative amount with up to two decimals.'
                      : null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Opening notes (optional)',
                ),
                maxLines: 2,
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
          onPressed: saving ? null : _open,
          child: Text(saving ? 'Opening…' : 'Open shift'),
        ),
      ],
    );
  }

  Future<void> _open() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final result = await ref
        .read(shiftMutationControllerProvider.notifier)
        .openShift(
          OpenShiftDraft(
            registerId: _registerId!,
            deviceId: widget.deviceId,
            openingCashMinor: Formatters.parseCurrencyMinor(
              _openingController.text,
            )!,
            notes: _notesController.text,
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
