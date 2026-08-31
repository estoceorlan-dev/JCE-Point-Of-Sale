import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/stock_transfer.dart';
import '../controllers/transfer_mutation_controller.dart';
import '../providers/transfers_providers.dart';

class CreateTransferDialog extends ConsumerStatefulWidget {
  const CreateTransferDialog({super.key});

  @override
  ConsumerState<CreateTransferDialog> createState() =>
      _CreateTransferDialogState();
}

class _CreateTransferDialogState extends ConsumerState<CreateTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _lines = <_DraftLineInput>[_DraftLineInput()];
  String? _destinationBranchId;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(transferOptionsProvider).value;
    final session = ref.watch(activeTransferSessionProvider);
    final saving = ref.watch(transferMutationControllerProvider).isLoading;
    final branches =
        options?.branches
            .where((branch) => branch.id != session?.activeBranchId)
            .toList(growable: false) ??
        const <TransferBranchOption>[];
    final sourceLocations =
        options?.locations
            .where((location) => location.branchId == session?.activeBranchId)
            .toList(growable: false) ??
        const <TransferLocationOption>[];
    final destinationLocations =
        options?.locations
            .where((location) => location.branchId == _destinationBranchId)
            .toList(growable: false) ??
        const <TransferLocationOption>[];
    return AlertDialog(
      title: const Text('New stock transfer'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _destinationBranchId,
                  decoration: const InputDecoration(
                    labelText: 'Destination branch',
                  ),
                  items: [
                    for (final branch in branches)
                      DropdownMenuItem(
                        value: branch.id,
                        child: Text('${branch.code} — ${branch.name}'),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() {
                          _destinationBranchId = value;
                          for (final line in _lines) {
                            line.destinationStockLocationId = null;
                          }
                        }),
                  validator: (value) =>
                      value == null ? 'Select a destination branch.' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (var index = 0; index < _lines.length; index++) ...[
                  _TransferLineEditor(
                    key: ValueKey(_lines[index]),
                    index: index,
                    line: _lines[index],
                    products: options?.products ?? const [],
                    sourceLocations: sourceLocations,
                    destinationLocations: destinationLocations,
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
                      : () => setState(() => _lines.add(_DraftLineInput())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Transfer notes (optional)',
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
      final removed = _lines.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final result = await ref
        .read(transferMutationControllerProvider.notifier)
        .create(
          StockTransferDraft(
            destinationBranchId: _destinationBranchId!,
            notes: _notesController.text,
            lines: [
              for (final line in _lines)
                StockTransferLineDraft(
                  productId: line.productId!,
                  sourceStockLocationId: line.sourceStockLocationId!,
                  destinationStockLocationId: line.destinationStockLocationId!,
                  quantityMilli: Formatters.parseQuantityMilli(
                    line.quantityController.text,
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

class _TransferLineEditor extends StatelessWidget {
  const _TransferLineEditor({
    super.key,
    required this.index,
    required this.line,
    required this.products,
    required this.sourceLocations,
    required this.destinationLocations,
    required this.enabled,
    this.onRemove,
  });

  final int index;
  final _DraftLineInput line;
  final List<TransferProductOption> products;
  final List<TransferLocationOption> sourceLocations;
  final List<TransferLocationOption> destinationLocations;
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
                Text(
                  'Item ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove item',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: line.productId,
                    decoration: const InputDecoration(labelText: 'Product'),
                    items: [
                      for (final product in products)
                        DropdownMenuItem(
                          value: product.id,
                          child: Text('${product.sku} — ${product.name}'),
                        ),
                    ],
                    onChanged: enabled
                        ? (value) => line.productId = value
                        : null,
                    validator: (value) =>
                        value == null ? 'Select a product.' : null,
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: line.sourceStockLocationId,
                    decoration: const InputDecoration(labelText: 'From'),
                    items: [
                      for (final location in sourceLocations)
                        DropdownMenuItem(
                          value: location.id,
                          child: Text(location.name),
                        ),
                    ],
                    onChanged: enabled
                        ? (value) => line.sourceStockLocationId = value
                        : null,
                    validator: (value) =>
                        value == null ? 'Select source.' : null,
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: line.destinationStockLocationId,
                    decoration: const InputDecoration(labelText: 'To'),
                    items: [
                      for (final location in destinationLocations)
                        DropdownMenuItem(
                          value: location.id,
                          child: Text(location.name),
                        ),
                    ],
                    onChanged: enabled
                        ? (value) => line.destinationStockLocationId = value
                        : null,
                    validator: (value) =>
                        value == null ? 'Select destination.' : null,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    controller: line.quantityController,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftLineInput {
  final quantityController = TextEditingController();
  String? productId;
  String? sourceStockLocationId;
  String? destinationStockLocationId;

  void dispose() => quantityController.dispose();
}
