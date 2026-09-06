import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/branch_profile.dart';

class BranchFormDialog extends StatefulWidget {
  const BranchFormDialog({super.key, this.branch});

  final BranchProfile? branch;

  @override
  State<BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<BranchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _timezone;
  late final TextEditingController _addressOne;
  late final TextEditingController _addressTwo;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _postalCode;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _receiptName;

  @override
  void initState() {
    super.initState();
    final branch = widget.branch;
    _code = TextEditingController(text: branch?.code ?? '');
    _name = TextEditingController(text: branch?.name ?? '');
    _timezone = TextEditingController(text: branch?.timezone ?? 'Asia/Manila');
    _addressOne = TextEditingController(text: branch?.addressLineOne ?? '');
    _addressTwo = TextEditingController(text: branch?.addressLineTwo ?? '');
    _city = TextEditingController(text: branch?.city ?? '');
    _province = TextEditingController(text: branch?.province ?? '');
    _postalCode = TextEditingController(text: branch?.postalCode ?? '');
    _phone = TextEditingController(text: branch?.phone ?? '');
    _email = TextEditingController(text: branch?.email ?? '');
    _receiptName = TextEditingController(
      text: branch?.receiptDisplayName ?? '',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _timezone,
      _addressOne,
      _addressTwo,
      _city,
      _province,
      _postalCode,
      _phone,
      _email,
      _receiptName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.branch == null ? 'Add branch' : 'Edit branch'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _field(_code, 'Branch code', required: true),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: _field(_name, 'Branch name', required: true),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _field(_timezone, 'IANA timezone', required: true),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _field(_receiptName, 'Receipt display name'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _field(_addressOne, 'Address line 1'),
                const SizedBox(height: AppSpacing.md),
                _field(_addressTwo, 'Address line 2'),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: _field(_city, 'City / municipality')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _field(_province, 'Province')),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 130,
                      child: _field(_postalCode, 'Postal code'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: _field(_phone, 'Phone')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _field(_email, 'Email')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.branch == null ? 'Add branch' : 'Save changes'),
        ),
      ],
    );
  }

  TextFormField _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    validator: required
        ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
        : null,
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      BranchDraft(
        code: _code.text,
        name: _name.text,
        timezone: _timezone.text,
        addressLineOne: _addressOne.text,
        addressLineTwo: _addressTwo.text,
        city: _city.text,
        province: _province.text,
        postalCode: _postalCode.text,
        phone: _phone.text,
        email: _email.text,
        receiptDisplayName: _receiptName.text,
      ),
    );
  }
}
