import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_correction.dart';
import '../controllers/sale_correction_controller.dart';
import '../providers/pos_providers.dart';

class SaleCorrectionDialog extends ConsumerStatefulWidget {
  const SaleCorrectionDialog({
    required this.sale,
    required this.type,
    super.key,
  });

  final SaleRecord sale;
  final SaleCorrectionType type;

  @override
  ConsumerState<SaleCorrectionDialog> createState() =>
      _SaleCorrectionDialogState();
}

class _SaleCorrectionDialogState extends ConsumerState<SaleCorrectionDialog> {
  late final List<_LineForm> _lines;
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _referenceController = TextEditingController();
  RefundMethod _refundMethod = RefundMethod.cash;
  bool _approveAsManager = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lines = [
      for (final item in widget.sale.items)
        if (item.returnableQuantityMilli > 0)
          _LineForm(
            item: item,
            selected: widget.type == SaleCorrectionType.voidSale,
            quantityController: TextEditingController(
              text: widget.type == SaleCorrectionType.voidSale
                  ? Formatters.quantityMilli(item.returnableQuantityMilli)
                  : '',
            ),
            destinationId: item.stockLocationId,
          ),
    ];
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.quantityController.dispose();
    }
    _reasonController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = ref.watch(returnDestinationsProvider);
    final submitting = ref.watch(saleCorrectionControllerProvider).isLoading;
    final canApprove =
        ref
            .watch(activePosSessionProvider)
            ?.can(AppPermission.approveSaleCorrections) ??
        false;
    final total = _estimatedTotal();
    return AlertDialog(
      title: Text(
        widget.type == SaleCorrectionType.voidSale
            ? 'Void ${widget.sale.receiptNumber}'
            : 'Return items from ${widget.sale.receiptNumber}',
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.type == SaleCorrectionType.voidSale
                    ? 'A void creates a full compensating correction. The original receipt remains unchanged.'
                    : 'Select the quantities to return. Previously returned quantities are unavailable.',
              ),
              const SizedBox(height: AppSpacing.lg),
              destinations.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Text('Return destinations could not be loaded: $error'),
                data: (locations) => Column(
                  children: [
                    for (final line in _lines)
                      _CorrectionLineEditor(
                        line: line,
                        destinations: locations,
                        locked: widget.type == SaleCorrectionType.voidSale,
                        onChanged: () => setState(() {}),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason code',
                  hintText: 'Example: CUSTOMER_RETURN',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<RefundMethod>(
                      initialValue: _refundMethod,
                      decoration: const InputDecoration(
                        labelText: 'Refund method',
                      ),
                      items: [
                        for (final method in RefundMethod.values)
                          DropdownMenuItem(
                            value: method,
                            child: Text(method.label),
                          ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) => setState(
                              () => _refundMethod = value ?? _refundMethod,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Refund reference (optional)',
                      ),
                    ),
                  ),
                ],
              ),
              if (canApprove) ...[
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _approveAsManager,
                  title: const Text('Approve as manager if policy requires it'),
                  subtitle: const Text(
                    'Approval is stored as a request and decision linked to this correction.',
                  ),
                  onChanged: submitting
                      ? null
                      : (value) =>
                            setState(() => _approveAsManager = value ?? false),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Refund total: ${Formatters.currencyMinor(total)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: submitting ? null : _submit,
          child: Text(submitting ? 'Saving…' : widget.type.label),
        ),
      ],
    );
  }

  int _estimatedTotal() {
    var total = 0;
    for (final line in _lines.where((line) => line.selected)) {
      final quantity = Formatters.parseQuantityMilli(
        line.quantityController.text,
      );
      if (quantity == null || quantity <= 0) continue;
      final priorTotal = widget.sale.corrections
          .where((correction) => correction.status == 'completed')
          .expand((correction) => correction.items)
          .where((item) => item.saleItemId == line.item.id)
          .fold<int>(0, (sum, item) => sum + item.totalMinor);
      final finalQuantity = quantity == line.item.returnableQuantityMilli;
      total += finalQuantity
          ? line.item.totalAmountMinor - priorTotal
          : (line.item.totalAmountMinor * quantity +
                    line.item.quantityMilli ~/ 2) ~/
                line.item.quantityMilli;
    }
    return total;
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    final destinations = ref.read(returnDestinationsProvider).valueOrNull ?? [];
    final lines = <SaleCorrectionLineDraft>[];
    for (final form in _lines.where((line) => line.selected)) {
      final quantity = Formatters.parseQuantityMilli(
        form.quantityController.text,
      );
      if (quantity == null ||
          quantity <= 0 ||
          quantity > form.item.returnableQuantityMilli) {
        setState(() {
          _error =
              'Enter a valid returnable quantity for ${form.item.productName}.';
        });
        return;
      }
      String? destinationId;
      if (form.disposition.changesInventory) {
        final candidates = _destinationsFor(form.disposition, destinations);
        destinationId =
            candidates.any(
              (destination) =>
                  destination.stockLocationId == form.destinationId,
            )
            ? form.destinationId
            : candidates.firstOrNull?.stockLocationId;
        if (destinationId == null) {
          setState(() {
            _error =
                'Configure an active ${form.disposition.label.toLowerCase()} location first.';
          });
          return;
        }
      }
      lines.add(
        SaleCorrectionLineDraft(
          saleItemId: form.item.id,
          quantityMilli: quantity,
          disposition: form.disposition,
          destinationStockLocationId: destinationId,
        ),
      );
    }
    final total = _estimatedTotal();
    if (lines.isEmpty || reason.isEmpty || total <= 0) {
      setState(() {
        _error = 'Select at least one item and enter a reason code.';
      });
      return;
    }
    setState(() => _error = null);
    final result = await ref
        .read(saleCorrectionControllerProvider.notifier)
        .correct(
          saleId: widget.sale.id,
          type: widget.type,
          lines: lines,
          refunds: [
            RefundDraft(
              method: _refundMethod,
              amountMinor: total,
              reference: _referenceController.text,
            ),
          ],
          reasonCode: reason,
          notes: _notesController.text,
          approveAsManager: _approveAsManager,
        );
    if (!mounted) return;
    if (result.isFailure) {
      setState(() => _error = result.failureOrNull!.message);
      return;
    }
    Navigator.pop(context, result.valueOrNull);
  }
}

class _CorrectionLineEditor extends StatelessWidget {
  const _CorrectionLineEditor({
    required this.line,
    required this.destinations,
    required this.locked,
    required this.onChanged,
  });

  final _LineForm line;
  final List<ReturnDestination> destinations;
  final bool locked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = _destinationsFor(line.disposition, destinations);
    final selectedDestination =
        choices.any(
          (destination) => destination.stockLocationId == line.destinationId,
        )
        ? line.destinationId
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: line.selected,
                  onChanged: locked
                      ? null
                      : (value) {
                          line.selected = value ?? false;
                          if (line.selected &&
                              line.quantityController.text.isEmpty) {
                            line.quantityController.text =
                                Formatters.quantityMilli(
                                  line.item.returnableQuantityMilli,
                                );
                          }
                          onChanged();
                        },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.item.productName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${line.item.sku} · Returnable ${Formatters.quantityMilli(line.item.returnableQuantityMilli)} ${line.item.unitName}',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: line.quantityController,
                    enabled: line.selected && !locked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            if (line.selected) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ReturnDisposition>(
                      initialValue: line.disposition,
                      decoration: const InputDecoration(
                        labelText: 'Stock disposition',
                      ),
                      items: [
                        for (final disposition in ReturnDisposition.values)
                          DropdownMenuItem(
                            value: disposition,
                            child: Text(disposition.label),
                          ),
                      ],
                      onChanged: (value) {
                        line.disposition = value ?? line.disposition;
                        line.destinationId = null;
                        onChanged();
                      },
                    ),
                  ),
                  if (line.disposition.changesInventory) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedDestination,
                        decoration: const InputDecoration(
                          labelText: 'Destination',
                        ),
                        items: [
                          for (final destination in choices)
                            DropdownMenuItem(
                              value: destination.stockLocationId,
                              child: Text(destination.name),
                            ),
                        ],
                        onChanged: (value) {
                          line.destinationId = value;
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineForm {
  _LineForm({
    required this.item,
    required this.selected,
    required this.quantityController,
    required this.destinationId,
  });

  final SaleItem item;
  bool selected;
  final TextEditingController quantityController;
  ReturnDisposition disposition = ReturnDisposition.restock;
  String? destinationId;
}

List<ReturnDestination> _destinationsFor(
  ReturnDisposition disposition,
  List<ReturnDestination> destinations,
) {
  return switch (disposition) {
    ReturnDisposition.restock =>
      destinations
          .where((destination) => destination.locationType != 'damaged')
          .toList(growable: false),
    ReturnDisposition.damaged =>
      destinations
          .where((destination) => destination.locationType == 'damaged')
          .toList(growable: false),
    ReturnDisposition.nonRestock => const [],
  };
}
