import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/supplier.dart';
import '../controllers/purchase_mutation_controller.dart';

class CreateSupplierDialog extends ConsumerStatefulWidget {
  const CreateSupplierDialog({super.key});

  @override
  ConsumerState<CreateSupplierDialog> createState() =>
      _CreateSupplierDialogState();
}

class _CreateSupplierDialogState extends ConsumerState<CreateSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _taxId = TextEditingController();
  final _terms = TextEditingController(text: '0');
  final _contactName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _taxId.dispose();
    _terms.dispose();
    _contactName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(purchaseMutationControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('New supplier'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _code,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Supplier code',
                        ),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _name,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Supplier name',
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _taxId,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Tax identifier (optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _terms,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Payment terms (days)',
                        ),
                        validator: (value) {
                          final days = int.tryParse(value?.trim() ?? '');
                          return days == null || days < 0
                              ? 'Enter zero or more days.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Primary contact (optional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _contactName,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Contact name'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _email,
                        enabled: !saving,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _phone,
                        enabled: !saving,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                    ),
                  ],
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
          child: Text(saving ? 'Saving…' : 'Save supplier'),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final contactName = _contactName.text.trim();
    if (contactName.isNotEmpty &&
        _email.text.trim().isEmpty &&
        _phone.text.trim().isEmpty) {
      setState(() => _error = 'Add an email or phone for the contact.');
      return;
    }
    setState(() => _error = null);
    final result = await ref
        .read(purchaseMutationControllerProvider.notifier)
        .createSupplier(
          SupplierDraft(
            code: _code.text,
            name: _name.text,
            taxIdentifier: _taxId.text,
            paymentTermsDays: int.parse(_terms.text.trim()),
            contacts: contactName.isEmpty
                ? const []
                : [
                    SupplierContactDraft(
                      name: contactName,
                      email: _email.text,
                      phone: _phone.text,
                      isPrimary: true,
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
