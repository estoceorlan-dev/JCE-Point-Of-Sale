import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/cash_shift.dart';
import '../controllers/shift_mutation_controller.dart';
import '../providers/shift_providers.dart';

class CloseShiftDialog extends ConsumerStatefulWidget {
  const CloseShiftDialog({super.key, required this.shift});

  final CashShift shift;

  @override
  ConsumerState<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends ConsumerState<CloseShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<ShiftPaymentMethod, TextEditingController> _controllers;
  final _notesController = TextEditingController();
  final _approvalNotesController = TextEditingController();
  bool _approveAsManager = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = {
      ShiftPaymentMethod.cash: TextEditingController(
        text: _minorInput(widget.shift.expectedCashMinor),
      ),
      ShiftPaymentMethod.card: TextEditingController(text: '0.00'),
      ShiftPaymentMethod.eWallet: TextEditingController(text: '0.00'),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _notesController.dispose();
    _approvalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(shiftMutationControllerProvider).isLoading;
    final session = ref.watch(activeShiftSessionProvider);
    final canApprove =
        session?.can(AppPermission.approveShiftDiscrepancies) ?? false;
    final policy = ref.watch(shiftPolicyProvider).value;
    return AlertDialog(
      title: const Text('Close shift'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.shift.registerName} • Expected cash ${Formatters.currencyMinor(widget.shift.expectedCashMinor)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final method in ShiftPaymentMethod.values) ...[
                  TextFormField(
                    controller: _controllers[method],
                    decoration: InputDecoration(
                      labelText: '${method.label} counted',
                      prefixText: 'PHP ',
                      helperText: method == ShiftPaymentMethod.cash
                          ? 'Expected: ${Formatters.currencyMinor(widget.shift.expectedCashMinor)}'
                          : 'Expected sales totals are added in Phase 6.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final minor = Formatters.parseCurrencyMinor(value ?? '');
                      return minor == null || minor < 0
                          ? 'Enter a non-negative amount.'
                          : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Closing notes (optional)',
                  ),
                  maxLines: 2,
                ),
                if (policy?.cashDiscrepancyApprovalThresholdMinor
                    case final threshold?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Manager approval is required when the cash discrepancy exceeds ${Formatters.currencyMinor(threshold)}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (canApprove) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Approve discrepancy as manager'),
                    value: _approveAsManager,
                    onChanged: saving
                        ? null
                        : (value) => setState(
                            () => _approveAsManager = value ?? false,
                          ),
                  ),
                  if (_approveAsManager)
                    TextFormField(
                      controller: _approvalNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Approval notes',
                      ),
                      validator: (value) =>
                          _approveAsManager && (value?.trim().length ?? 0) < 2
                          ? 'Enter approval notes.'
                          : null,
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _close,
          child: Text(saving ? 'Closing…' : 'Close shift'),
        ),
      ],
    );
  }

  Future<void> _close() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final result = await ref
        .read(shiftMutationControllerProvider.notifier)
        .closeShift(
          CloseShiftDraft(
            shiftId: widget.shift.id,
            countedAmountsMinor: {
              for (final entry in _controllers.entries)
                entry.key: Formatters.parseCurrencyMinor(entry.value.text)!,
            },
            expectedVersion: widget.shift.version,
            notes: _notesController.text,
            approvalNotes: _approvalNotesController.text,
          ),
          approveAsManager: _approveAsManager,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}

String _minorInput(int minor) {
  final sign = minor < 0 ? '-' : '';
  final absolute = minor.abs();
  return '$sign${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
}
