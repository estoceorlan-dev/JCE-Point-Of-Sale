import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/purchase_order.dart';
import '../controllers/purchase_mutation_controller.dart';
import '../providers/purchases_providers.dart';

class CreatePurchaseOrderDialog extends ConsumerStatefulWidget {
  const CreatePurchaseOrderDialog({super.key});

  @override
  ConsumerState<CreatePurchaseOrderDialog> createState() =>
      _CreatePurchaseOrderDialogState();
}

class _CreatePurchaseOrderDialogState
    extends ConsumerState<CreatePurchaseOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _lines = <_OrderLineInput>[_OrderLineInput()];
  String? _supplierId;
  String? _error;

  @override
  void dispose() {
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
      title: const Text('New purchase order'),
      content: SizedBox(
        width: 780,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    for (final supplier in options?.suppliers ?? const [])
                      DropdownMenuItem(
                        value: supplier.id,
                        child: Text('${supplier.code} — ${supplier.name}'),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => _supplierId = value),
                  validator: (value) =>
                      value == null ? 'Select a supplier.' : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                for (var index = 0; index < _lines.length; index++) ...[
                  _PurchaseLineEditor(
                    key: ValueKey(_lines[index]),
                    index: index,
                    input: _lines[index],
                    products: options?.products ?? const [],
                    enabled: !saving,
                    onRemove: _lines.length == 1
                        ? null
                        : () => _removeLine(index),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () => setState(() => _lines.add(_OrderLineInput())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _notes,
                  enabled: !saving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Order notes (optional)',
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
          child: Text(saving ? 'Saving…' : 'Save draft'),
        ),
      ],
    );
  }

  void _removeLine(int index) {
    setState(() {
      final line = _lines.removeAt(index);
      line.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final result = await ref
        .read(purchaseMutationControllerProvider.notifier)
        .createOrder(
          PurchaseOrderDraft(
            supplierId: _supplierId!,
            notes: _notes.text,
            lines: [
              for (final line in _lines)
                PurchaseOrderLineDraft(
                  productId: line.productId!,
                  orderedQuantityMilli: Formatters.parseQuantityMilli(
                    line.quantity.text,
                  )!,
                  unitCostMinor: Formatters.parseCurrencyMinor(
                    line.unitCost.text,
                  )!,
                  estimatedLandedCostMinor: Formatters.parseCurrencyMinor(
                    line.landedCost.text,
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

class _PurchaseLineEditor extends StatelessWidget {
  const _PurchaseLineEditor({
    super.key,
    required this.index,
    required this.input,
    required this.products,
    required this.enabled,
    required this.onRemove,
  });

  final int index;
  final _OrderLineInput input;
  final List<PurchaseProductOption> products;
  final bool enabled;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Item ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove item',
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: input.productId,
              decoration: const InputDecoration(labelText: 'Product'),
              items: [
                for (final product in products)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text('${product.sku} — ${product.name}'),
                  ),
              ],
              onChanged: enabled ? (value) => input.productId = value : null,
              validator: (value) => value == null ? 'Select a product.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: input.quantity,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    validator: (value) {
                      final quantity = Formatters.parseQuantityMilli(
                        value ?? '',
                      );
                      return quantity == null || quantity <= 0
                          ? 'Enter a positive quantity.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: input.unitCost,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Unit cost'),
                    validator: _costValidator,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: input.landedCost,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Est. landed / unit',
                    ),
                    validator: _costValidator,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String? _costValidator(String? value) {
    final cost = Formatters.parseCurrencyMinor(value ?? '');
    return cost == null || cost < 0 ? 'Enter a non-negative cost.' : null;
  }
}

class _OrderLineInput {
  String? productId;
  final quantity = TextEditingController(text: '1');
  final unitCost = TextEditingController(text: '0.00');
  final landedCost = TextEditingController(text: '0.00');

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
    landedCost.dispose();
  }
}
