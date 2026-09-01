import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/goods_receipt.dart';
import '../../domain/entities/purchase_order.dart';
import '../controllers/purchase_mutation_controller.dart';
import '../providers/purchases_providers.dart';

class ReceivePurchaseOrderDialog extends ConsumerStatefulWidget {
  const ReceivePurchaseOrderDialog({required this.order, super.key});

  final PurchaseOrder order;

  @override
  ConsumerState<ReceivePurchaseOrderDialog> createState() =>
      _ReceivePurchaseOrderDialogState();
}

class _ReceivePurchaseOrderDialogState
    extends ConsumerState<ReceivePurchaseOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierDocument = TextEditingController();
  final _notes = TextEditingController();
  late final List<_ReceiptLineInput> _lines;
  String? _locationId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lines = [
      for (final line in widget.order.lines)
        if (line.remainingQuantityMilli > 0) _ReceiptLineInput(line),
    ];
  }

  @override
  void dispose() {
    _supplierDocument.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(purchaseOptionsProvider).value;
    final saving = ref.watch(purchaseMutationControllerProvider).isLoading;
    return AlertDialog(
      title: Text('Receive ${widget.order.orderNumber}'),
      content: SizedBox(
        width: 840,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _locationId,
                  decoration: const InputDecoration(
                    labelText: 'Receiving location',
                  ),
                  items: [
                    for (final location in options?.locations ?? const [])
                      DropdownMenuItem(
                        value: location.id,
                        child: Text(location.name),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => _locationId = value),
                  validator: (value) =>
                      value == null ? 'Select a receiving location.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _supplierDocument,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Supplier delivery / invoice number (optional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'Enter this delivery only. Unreceived quantities remain open for another receipt.',
                ),
                const SizedBox(height: AppSpacing.md),
                for (final line in _lines) ...[
                  _ReceiptLineEditor(input: line, enabled: !saving),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _notes,
                  enabled: !saving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Receiving notes (optional)',
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
        FilledButton.icon(
          onPressed: saving ? null : _receive,
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(saving ? 'Receiving…' : 'Post receipt'),
        ),
      ],
    );
  }

  Future<void> _receive() async {
    if (!_formKey.currentState!.validate()) return;
    final selected = _lines
        .where(
          (line) =>
              (Formatters.parseQuantityMilli(line.quantity.text) ?? 0) > 0,
        )
        .toList(growable: false);
    if (selected.isEmpty) {
      setState(() => _error = 'Enter a quantity for at least one item.');
      return;
    }
    setState(() => _error = null);
    final result = await ref
        .read(purchaseMutationControllerProvider.notifier)
        .receive(
          widget.order,
          GoodsReceiptDraft(
            stockLocationId: _locationId!,
            supplierDocumentNumber: _supplierDocument.text,
            notes: _notes.text,
            lines: [
              for (final input in selected)
                GoodsReceiptLineDraft(
                  purchaseOrderItemId: input.line.id,
                  receivedQuantityMilli: Formatters.parseQuantityMilli(
                    input.quantity.text,
                  )!,
                  unitCostMinor: Formatters.parseCurrencyMinor(
                    input.unitCost.text,
                  )!,
                  freightCostMinor: Formatters.parseCurrencyMinor(
                    input.freight.text,
                  )!,
                  dutyCostMinor: Formatters.parseCurrencyMinor(
                    input.duty.text,
                  )!,
                  otherLandedCostMinor: Formatters.parseCurrencyMinor(
                    input.other.text,
                  )!,
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

class _ReceiptLineEditor extends StatelessWidget {
  const _ReceiptLineEditor({required this.input, required this.enabled});

  final _ReceiptLineInput input;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${input.line.sku} — ${input.line.productName}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Remaining: ${Formatters.quantityMilli(input.line.remainingQuantityMilli)}',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _CostField(
                  width: 130,
                  controller: input.quantity,
                  enabled: enabled,
                  label: 'Received qty',
                  validator: (value) {
                    final quantity = Formatters.parseQuantityMilli(value ?? '');
                    if (quantity == null || quantity < 0) {
                      return 'Invalid quantity.';
                    }
                    if (quantity > input.line.remainingQuantityMilli) {
                      return 'Exceeds remaining.';
                    }
                    return null;
                  },
                ),
                _CostField(
                  controller: input.unitCost,
                  enabled: enabled,
                  label: 'Unit cost',
                ),
                _CostField(
                  controller: input.freight,
                  enabled: enabled,
                  label: 'Freight total',
                ),
                _CostField(
                  controller: input.duty,
                  enabled: enabled,
                  label: 'Duty total',
                ),
                _CostField(
                  controller: input.other,
                  enabled: enabled,
                  label: 'Other landed',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CostField extends StatelessWidget {
  const _CostField({
    required this.controller,
    required this.enabled,
    required this.label,
    this.width = 125,
    this.validator,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final double width;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: validator ?? _costValidator,
      ),
    );
  }

  String? _costValidator(String? value) {
    final cost = Formatters.parseCurrencyMinor(value ?? '');
    return cost == null || cost < 0 ? 'Invalid cost.' : null;
  }
}

class _ReceiptLineInput {
  _ReceiptLineInput(this.line)
    : quantity = TextEditingController(
        text: Formatters.quantityMilli(line.remainingQuantityMilli),
      ),
      unitCost = TextEditingController(
        text: (line.unitCostMinor / 100).toStringAsFixed(2),
      );

  final PurchaseOrderLine line;
  final TextEditingController quantity;
  final TextEditingController unitCost;
  final freight = TextEditingController(text: '0.00');
  final duty = TextEditingController(text: '0.00');
  final other = TextEditingController(text: '0.00');

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
    freight.dispose();
    duty.dispose();
    other.dispose();
  }
}
