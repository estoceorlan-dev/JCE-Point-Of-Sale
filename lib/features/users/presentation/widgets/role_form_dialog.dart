import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../domain/entities/staff_account.dart';

class RoleFormDialog extends StatefulWidget {
  const RoleFormDialog({this.role, super.key});

  final RoleDefinition? role;

  @override
  State<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late Set<AppPermission> _permissions;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.role?.code);
    _name = TextEditingController(text: widget.role?.name);
    _description = TextEditingController(text: widget.role?.description);
    _permissions = {...?widget.role?.permissions};
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.role == null ? 'Create role' : 'Edit role'),
      content: SizedBox(
        width: 720,
        height: 620,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Role name'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'Stable role code',
                      ),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Permission matrix',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListView(
                    children: [
                      for (final group in _groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            group.key,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        for (final permission in group.value)
                          CheckboxListTile(
                            dense: true,
                            value: _permissions.contains(permission),
                            title: Text(_permissionLabel(permission)),
                            subtitle: Text(permission.code),
                            onChanged: (selected) => setState(() {
                              if (selected ?? false) {
                                _permissions.add(permission);
                              } else {
                                _permissions.remove(permission);
                              }
                            }),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save role')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_permissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one permission.')),
      );
      return;
    }
    Navigator.pop(
      context,
      RoleDraft(
        code: _code.text,
        name: _name.text,
        description: _description.text,
        permissions: _permissions,
      ),
    );
  }
}

String? _required(String? value) =>
    (value?.trim().isEmpty ?? true) ? 'Required' : null;

String _permissionLabel(AppPermission permission) => permission.code
    .split('.')
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' · ');

final Map<String, List<AppPermission>> _groups = {
  'Administration': [
    AppPermission.manageBranches,
    AppPermission.manageUsers,
    AppPermission.manageRoles,
    AppPermission.manageRegisters,
    AppPermission.manageSettings,
  ],
  'Catalog & stock': [
    AppPermission.manageProducts,
    AppPermission.manageInventory,
    AppPermission.approveInventoryAdjustments,
    AppPermission.receivePurchases,
    AppPermission.manageSuppliers,
    AppPermission.approveTransfers,
  ],
  'Point of sale': [
    AppPermission.processSales,
    AppPermission.approveShiftDiscrepancies,
    AppPermission.approveSaleDiscounts,
    AppPermission.processSaleReturns,
    AppPermission.approveSaleCorrections,
  ],
  'Insights': [AppPermission.viewReports, AppPermission.viewAuditLogs],
};
