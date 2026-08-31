import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/stock_transfer.dart';
import '../controllers/transfer_mutation_controller.dart';
import '../providers/transfers_providers.dart';

class ReceiveTransferDialog extends ConsumerStatefulWidget {
  const ReceiveTransferDialog({
    super.key,
    required this.transfer,
    this.correction = false,
  });

  final StockTransfer transfer;
  final bool correction;

  @override
  ConsumerState<ReceiveTransferDialog> createState() =>
      _ReceiveTransferDialogState();
}

class _ReceiveTransferDialogState extends ConsumerState<ReceiveTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  late final Map<String, _ReceiptInput> _inputs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inputs = {
      for (final line in widget.transfer.lines)
        line.id: _ReceiptInput(
          received: widget.correction
              ? line.receivedQuantityMilli
              : line.shippedQuantityMilli,
          damaged: widget.correction ? line.damagedQuantityMilli : 0,
          damagedLocationId: widget.correction
              ? line.damagedStockLocationId
              : null,
        ),
    };
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    for (final input in _inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(transferOptionsProvider).value;
    final damagedLocations =
        options?.locations
            .where(
              (location) =>
                  location.branchId == widget.transfer.destinationBranchId &&
                  location.locationType == 'damaged',
            )
            .toList(growable: false) ??
        const <TransferLocationOption>[];
    final saving = ref.watch(transferMutationControllerProvider).isLoading;
    return AlertDialog(
      title: Text(
        widget.correction ? 'Correct transfer receipt' : 'Receive transfer',
      ),
      content: SizedBox(
        width: 700,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.transfer.transferNumber),
                const SizedBox(height: AppSpacing.lg),
                for (final line in widget.transfer.lines) ...[
                  _ReceiptLineEditor(
                    line: line,
                    input: _inputs[line.id]!,
                    damagedLocations: damagedLocations,
                    enabled: !saving,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (widget.correction) ...[
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Correction reason',
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'A correction reason is required.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
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
          onPressed: saving ? null : _save,
          child: Text(
            saving
                ? 'Saving…'
                : widget.correction
                ? 'Approve correction'
                : 'Complete receipt',
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final controller = ref.read(transferMutationControllerProvider.notifier);
    final result = widget.correction
        ? await controller.correctReceipt(
            widget.transfer,
            TransferCorrectionDraft(
              reason: _reasonController.text,
              notes: _notesController.text,
              lines: [
                for (final line in widget.transfer.lines)
                  TransferCorrectionLineDraft(
                    transferItemId: line.id,
                    receivedQuantityMilli: _inputs[line.id]!.received,
                    damagedQuantityMilli: _inputs[line.id]!.damaged,
                    damagedStockLocationId: _inputs[line.id]!.damagedLocationId,
                  ),
              ],
            ),
          )
        : await controller.receive(
            widget.transfer,
            TransferReceiptDraft(
              notes: _notesController.text,
              lines: [
                for (final line in widget.transfer.lines)
                  TransferReceiptLineDraft(
                    transferItemId: line.id,
                    receivedQuantityMilli: _inputs[line.id]!.received,
                    damagedQuantityMilli: _inputs[line.id]!.damaged,
                    damagedStockLocationId: _inputs[line.id]!.damagedLocationId,
                  ),
              ],
            ),
          );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}

class _ReceiptLineEditor extends StatefulWidget {
  const _ReceiptLineEditor({
    required this.line,
    required this.input,
    required this.damagedLocations,
    required this.enabled,
  });

  final StockTransferLine line;
  final _ReceiptInput input;
  final List<TransferLocationOption> damagedLocations;
  final bool enabled;

  @override
  State<_ReceiptLineEditor> createState() => _ReceiptLineEditorState();
}

class _ReceiptLineEditorState extends State<_ReceiptLineEditor> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.line.sku} — ${widget.line.productName}'),
            Text(
              'Shipped ${Formatters.quantityMilli(widget.line.shippedQuantityMilli)} to ${widget.line.destinationLocationName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    controller: widget.input.receivedController,
                    enabled: widget.enabled,
                    decoration: const InputDecoration(labelText: 'Received'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (_) => _validateQuantities(),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    controller: widget.input.damagedController,
                    enabled: widget.enabled,
                    decoration: const InputDecoration(labelText: 'Damaged'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (_) => _validateQuantities(),
                  ),
                ),
                if (widget.input.damaged > 0)
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: widget.input.damagedLocationId,
                      decoration: const InputDecoration(
                        labelText: 'Damaged location',
                      ),
                      items: [
                        for (final location in widget.damagedLocations)
                          DropdownMenuItem(
                            value: location.id,
                            child: Text(location.name),
                          ),
                      ],
                      onChanged: widget.enabled
                          ? (value) => widget.input.damagedLocationId = value
                          : null,
                      validator: (value) =>
                          widget.input.damaged > 0 && value == null
                          ? 'Select a damaged location.'
                          : null,
                    ),
                  ),
              ],
            ),
            Text(
              'Discrepancy: ${Formatters.quantityMilli(widget.line.shippedQuantityMilli - widget.input.received - widget.input.damaged)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String? _validateQuantities() {
    if (widget.input.received < 0 ||
        widget.input.damaged < 0 ||
        widget.input.received + widget.input.damaged >
            widget.line.shippedQuantityMilli) {
      return 'Quantities cannot exceed shipped stock.';
    }
    return null;
  }
}

class _ReceiptInput {
  _ReceiptInput({
    required int received,
    required int damaged,
    required this.damagedLocationId,
  }) : receivedController = TextEditingController(
         text: Formatters.quantityMilli(received),
       ),
       damagedController = TextEditingController(
         text: Formatters.quantityMilli(damaged),
       );

  final TextEditingController receivedController;
  final TextEditingController damagedController;
  String? damagedLocationId;

  int get received =>
      Formatters.parseQuantityMilli(receivedController.text) ?? -1;
  int get damaged =>
      Formatters.parseQuantityMilli(damagedController.text) ?? -1;

  void dispose() {
    receivedController.dispose();
    damagedController.dispose();
  }
}
