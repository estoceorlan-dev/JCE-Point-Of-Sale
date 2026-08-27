import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/stock_count.dart';
import '../controllers/inventory_mutation_controller.dart';

class RecordStockCountDialog extends ConsumerStatefulWidget {
  const RecordStockCountDialog({
    super.key,
    required this.count,
    required this.item,
  });

  final StockCount count;
  final StockCountItem item;

  @override
  ConsumerState<RecordStockCountDialog> createState() =>
      _RecordStockCountDialogState();
}

class _RecordStockCountDialogState
    extends ConsumerState<RecordStockCountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.item.countedQuantityMilli == null
        ? ''
        : Formatters.quantityMilli(widget.item.countedQuantityMilli!),
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
      title: Text('Count ${widget.item.productName}'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Physical quantity',
            helperText:
                'Expected ${Formatters.quantityMilli(widget.item.expectedQuantityMilli)}',
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
          child: Text(saving ? 'Saving…' : 'Record count'),
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
        .recordCount(
          stockCountId: widget.count.id,
          itemId: widget.item.id,
          countedQuantityMilli: value,
          expectedVersion: widget.item.version,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
