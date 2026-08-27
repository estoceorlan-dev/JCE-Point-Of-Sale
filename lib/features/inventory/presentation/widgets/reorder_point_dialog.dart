import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/inventory_balance.dart';
import '../controllers/inventory_mutation_controller.dart';

class ReorderPointDialog extends ConsumerStatefulWidget {
  const ReorderPointDialog({super.key, required this.balance});

  final InventoryBalance balance;

  @override
  ConsumerState<ReorderPointDialog> createState() => _ReorderPointDialogState();
}

class _ReorderPointDialogState extends ConsumerState<ReorderPointDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: Formatters.quantityMilli(widget.balance.reorderPointMilli),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(inventoryMutationControllerProvider).isLoading;
    return AlertDialog(
      title: Text('Reorder point — ${widget.balance.productName}'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Reorder point',
            errorText: _error,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final value = Formatters.parseQuantityMilli(_controller.text);
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid non-negative quantity.');
      return;
    }
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .setReorderPoint(
          stockLocationId: widget.balance.stockLocationId,
          productId: widget.balance.productId,
          reorderPointMilli: value,
          expectedVersion: widget.balance.version,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
