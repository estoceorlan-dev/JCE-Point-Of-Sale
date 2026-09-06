import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../branches/domain/entities/branch_profile.dart';
import '../../domain/entities/staff_account.dart';

class StaffFormDialog extends StatefulWidget {
  const StaffFormDialog({
    required this.roles,
    required this.branches,
    this.account,
    super.key,
  });

  final StaffAccount? account;
  final List<RoleDefinition> roles;
  final List<BranchProfile> branches;

  @override
  State<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late List<StaffAssignmentDraft> _assignments;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.account?.displayName);
    _email = TextEditingController(text: widget.account?.email);
    _assignments =
        widget.account?.assignments
            .map(
              (item) => StaffAssignmentDraft(
                roleId: item.roleId,
                branchId: item.branchId,
              ),
            )
            .toList() ??
        <StaffAssignmentDraft>[];
    if (_assignments.isEmpty && widget.roles.isNotEmpty) {
      _assignments = [StaffAssignmentDraft(roleId: widget.roles.first.id)];
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.account == null ? 'Invite staff' : 'Edit staff account',
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter at least two characters.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (value) =>
                      !RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value?.trim() ?? '')
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Role assignments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose Organization for access across all branches, or limit a role to one branch.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (var index = 0; index < _assignments.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _assignments[index].roleId,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                            ),
                            items: [
                              for (final role in widget.roles)
                                DropdownMenuItem(
                                  value: role.id,
                                  child: Text(role.name),
                                ),
                            ],
                            onChanged: (roleId) {
                              if (roleId == null) return;
                              setState(
                                () =>
                                    _assignments[index] = StaffAssignmentDraft(
                                      roleId: roleId,
                                      branchId: _assignments[index].branchId,
                                    ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _assignments[index].branchId,
                            decoration: const InputDecoration(
                              labelText: 'Scope',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Organization'),
                              ),
                              for (final branch in widget.branches)
                                DropdownMenuItem<String?>(
                                  value: branch.id,
                                  child: Text(branch.name),
                                ),
                            ],
                            onChanged: (branchId) => setState(
                              () => _assignments[index] = StaffAssignmentDraft(
                                roleId: _assignments[index].roleId,
                                branchId: branchId,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove assignment',
                          onPressed: _assignments.length == 1
                              ? null
                              : () => setState(
                                  () => _assignments.removeAt(index),
                                ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: widget.roles.isEmpty
                      ? null
                      : () => setState(
                          () => _assignments.add(
                            StaffAssignmentDraft(roleId: widget.roles.first.id),
                          ),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add role'),
                ),
                if (widget.roles.isEmpty)
                  const Text('Create an active role before inviting staff.'),
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
          onPressed: widget.roles.isEmpty ? null : _submit,
          child: Text(
            widget.account == null ? 'Save invitation' : 'Save changes',
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      StaffDraft(
        email: _email.text,
        displayName: _name.text,
        assignments: _assignments,
      ),
    );
  }
}
