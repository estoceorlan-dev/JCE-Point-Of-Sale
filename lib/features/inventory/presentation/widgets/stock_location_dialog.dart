import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/stock_location.dart';
import '../controllers/inventory_mutation_controller.dart';

class StockLocationDialog extends ConsumerStatefulWidget {
  const StockLocationDialog({super.key});

  @override
  ConsumerState<StockLocationDialog> createState() =>
      _StockLocationDialogState();
}

class _StockLocationDialogState extends ConsumerState<StockLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  StockLocationType _type = StockLocationType.warehouse;
  bool _isDefault = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(inventoryMutationControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('New stock location'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Location code',
                  hintText: 'WAREHOUSE',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter at least two characters.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Location name'),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter a location name.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<StockLocationType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Location type'),
                items: [
                  for (final type in StockLocationType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => _type = value ?? _type),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default inventory location'),
                value: _isDefault,
                onChanged: saving
                    ? null
                    : (value) => setState(() => _isDefault = value),
              ),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
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
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Saving…' : 'Create location'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .createLocation(
          StockLocationDraft(
            code: _codeController.text,
            name: _nameController.text,
            type: _type,
            isDefault: _isDefault,
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
