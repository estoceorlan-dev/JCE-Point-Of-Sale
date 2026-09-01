import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/customer.dart';
import '../controllers/customer_mutation_controller.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  const CustomerFormDialog({this.profile, super.key});

  final CustomerProfile? profile;

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.profile?.customer.displayName,
  );
  late final _email = TextEditingController(
    text: widget.profile?.customer.email,
  );
  late final _phone = TextEditingController(
    text: widget.profile?.customer.phone,
  );
  late final _addressLabel = TextEditingController(
    text: widget.profile?.addresses.firstOrNull?.label ?? 'Home',
  );
  late final _street = TextEditingController(
    text: widget.profile?.addresses.firstOrNull?.lineOne,
  );
  late final _city = TextEditingController(
    text: widget.profile?.addresses.firstOrNull?.city,
  );
  late final _province = TextEditingController(
    text: widget.profile?.addresses.firstOrNull?.province,
  );
  late final _postalCode = TextEditingController(
    text: widget.profile?.addresses.firstOrNull?.postalCode,
  );
  late bool _marketingConsent =
      widget.profile?.customer.marketingConsent ?? false;
  late bool _enableLoyalty = widget.profile?.loyaltyAccount != null;
  bool _allowDuplicate = false;
  String? _error;

  bool get _editing => widget.profile != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _addressLabel.dispose();
    _street.dispose();
    _city.dispose();
    _province.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(customerMutationControllerProvider).isLoading;
    return AlertDialog(
      title: Text(_editing ? 'Edit customer' : 'New customer'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('customer-name-field'),
                  controller: _name,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Customer name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter at least two characters.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _email,
                        enabled: !saving,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _phone,
                        enabled: !saving,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Primary address',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _addressLabel,
                        enabled: !saving,
                        decoration: const InputDecoration(labelText: 'Label'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _street,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Street (optional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _city,
                        enabled: !saving,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _province,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Province',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _postalCode,
                        enabled: !saving,
                        decoration: const InputDecoration(labelText: 'Postal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _marketingConsent,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => _marketingConsent = value),
                  title: const Text('Marketing consent'),
                  subtitle: const Text(
                    'Store explicit consent; no consent is assumed from contact details.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _enableLoyalty,
                  onChanged: saving || widget.profile?.loyaltyAccount != null
                      ? null
                      : (value) => setState(() => _enableLoyalty = value),
                  title: const Text('Enable loyalty account'),
                  subtitle: const Text(
                    'Balances are maintained by immutable ledger entries.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _allowDuplicate,
                  onChanged: saving
                      ? null
                      : (value) =>
                            setState(() => _allowDuplicate = value ?? false),
                  title: const Text('Allow duplicate contact details'),
                  subtitle: const Text(
                    'Use only after confirming this is a separate person.',
                  ),
                ),
                if (_error case final error?)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
          key: const Key('save-customer-button'),
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Saving…' : 'Save customer'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final hasAddress =
        _street.text.trim().isNotEmpty || _city.text.trim().isNotEmpty;
    if (hasAddress &&
        (_street.text.trim().isEmpty || _city.text.trim().isEmpty)) {
      setState(() => _error = 'A saved address requires both street and city.');
      return;
    }
    final draft = CustomerDraft(
      displayName: _name.text,
      email: _email.text,
      phone: _phone.text,
      marketingConsent: _marketingConsent,
      enableLoyalty: _enableLoyalty,
      allowDuplicateContact: _allowDuplicate,
      addresses: hasAddress
          ? [
              CustomerAddressDraft(
                label: _addressLabel.text,
                lineOne: _street.text,
                city: _city.text,
                province: _province.text,
                postalCode: _postalCode.text,
                isPrimary: true,
              ),
            ]
          : const [],
    );
    final controller = ref.read(customerMutationControllerProvider.notifier);
    final result = _editing
        ? await controller.updateCustomer(widget.profile!.customer, draft)
        : await controller
              .create(draft)
              .then((result) => result.map<void>((_) {}));
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
