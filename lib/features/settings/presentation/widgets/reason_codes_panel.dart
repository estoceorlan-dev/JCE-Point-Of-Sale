import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/operational_setting.dart';
import '../../domain/entities/reason_code.dart';
import '../providers/settings_providers.dart';

class ReasonCodesPanel extends ConsumerWidget {
  const ReasonCodesPanel({required this.codes, super.key});

  final List<ReasonCode> codes;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason codes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Controlled reasons for adjustments, counts, returns, cash, and transfers.',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add reason'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (codes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('No configurable reason codes yet.')),
            )
          else
            for (final code in codes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  code.isActive
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                ),
                title: Text(code.label),
                subtitle: Text(
                  '${code.category.label} · ${code.code} · '
                  '${code.scope.name}${code.requiresNote ? ' · note required' : ''}',
                ),
                trailing: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    Switch(
                      value: code.isActive,
                      onChanged: (value) =>
                          _setActive(context, ref, code, value),
                    ),
                    IconButton(
                      tooltip: 'Edit reason code',
                      onPressed: () => _edit(context, ref, code: code),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    ReasonCode? code,
  }) async {
    final draft = await showDialog<ReasonCodeDraft>(
      context: context,
      builder: (context) => _ReasonCodeDialog(code: code),
    );
    if (draft == null || !context.mounted) return;
    final result = await ref
        .read(saveReasonCodeUseCaseProvider)
        .call(
          session: ref.read(authControllerProvider).asData?.value,
          draft: draft,
        );
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => _message(context, 'Reason code saved.'),
      onFailure: (failure) => _message(context, failure.message),
    );
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    ReasonCode code,
    bool isActive,
  ) async {
    final result = await ref
        .read(saveReasonCodeUseCaseProvider)
        .call(
          session: ref.read(authControllerProvider).asData?.value,
          draft: ReasonCodeDraft(
            id: code.id,
            category: code.category,
            code: code.code,
            label: code.label,
            requiresNote: code.requiresNote,
            isActive: isActive,
            sortOrder: code.sortOrder,
            scope: code.scope,
            expectedVersion: code.version,
          ),
        );
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => _message(
        context,
        isActive ? 'Reason code enabled.' : 'Reason code disabled.',
      ),
      onFailure: (failure) => _message(context, failure.message),
    );
  }

  void _message(BuildContext context, String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _ReasonCodeDialog extends StatefulWidget {
  const _ReasonCodeDialog({this.code});

  final ReasonCode? code;

  @override
  State<_ReasonCodeDialog> createState() => _ReasonCodeDialogState();
}

class _ReasonCodeDialogState extends State<_ReasonCodeDialog> {
  late final TextEditingController _code = TextEditingController(
    text: widget.code?.code ?? '',
  );
  late final TextEditingController _label = TextEditingController(
    text: widget.code?.label ?? '',
  );
  late ReasonCodeCategory _category =
      widget.code?.category ?? ReasonCodeCategory.inventoryAdjustment;
  late SettingScope _scope = widget.code?.scope ?? SettingScope.branch;
  late bool _requiresNote = widget.code?.requiresNote ?? false;

  @override
  void dispose() {
    _code.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.code == null ? 'Add reason code' : 'Edit reason code'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<ReasonCodeCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in ReasonCodeCategory.values)
                DropdownMenuItem(value: category, child: Text(category.label)),
            ],
            onChanged: widget.code == null
                ? (value) => setState(() => _category = value ?? _category)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _code,
            enabled: widget.code == null,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Code',
              hintText: 'DAMAGED_STOCK',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _label,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Display label'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<SettingScope>(
            initialValue: _scope,
            decoration: const InputDecoration(labelText: 'Scope'),
            items: const [
              DropdownMenuItem(
                value: SettingScope.organization,
                child: Text('Organization'),
              ),
              DropdownMenuItem(
                value: SettingScope.branch,
                child: Text('Active branch'),
              ),
            ],
            onChanged: widget.code == null
                ? (value) => setState(() => _scope = value ?? _scope)
                : null,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require an explanatory note'),
            value: _requiresNote,
            onChanged: (value) =>
                setState(() => _requiresNote = value ?? false),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          ReasonCodeDraft(
            id: widget.code?.id,
            category: _category,
            code: _code.text,
            label: _label.text,
            requiresNote: _requiresNote,
            isActive: widget.code?.isActive ?? true,
            sortOrder: widget.code?.sortOrder ?? 0,
            scope: _scope,
            expectedVersion: widget.code?.version,
          ),
        ),
        child: const Text('Save'),
      ),
    ],
  );
}
