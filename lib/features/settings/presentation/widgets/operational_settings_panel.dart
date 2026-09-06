import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/operational_setting.dart';
import '../providers/settings_providers.dart';

class OperationalSettingsPanel extends ConsumerStatefulWidget {
  const OperationalSettingsPanel({required this.settings, super.key});

  final OperationalSettings settings;

  @override
  ConsumerState<OperationalSettingsPanel> createState() =>
      _OperationalSettingsPanelState();
}

class _OperationalSettingsPanelState
    extends ConsumerState<OperationalSettingsPanel> {
  SettingScope _scope = SettingScope.branch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Behavior and policies',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Branch values take precedence over organization defaults.',
                      ),
                    ],
                  ),
                ),
                SegmentedButton<SettingScope>(
                  segments: const [
                    ButtonSegment(
                      value: SettingScope.organization,
                      label: Text('Organization default'),
                      icon: Icon(Icons.domain_outlined),
                    ),
                    ButtonSegment(
                      value: SettingScope.branch,
                      label: Text('Branch override'),
                      icon: Icon(Icons.storefront_outlined),
                    ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (selection) =>
                      setState(() => _scope = selection.single),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _group('Tax', [OperationalSettingKey.taxBehavior]),
            _group('Inventory', [
              OperationalSettingKey.inventoryAllowNegativeStock,
              OperationalSettingKey.inventoryAdjustmentApprovalThresholdMilli,
              OperationalSettingKey.transfersApprovalThresholdMilli,
            ]),
            _group('Receipts', [
              OperationalSettingKey.receiptHeader,
              OperationalSettingKey.receiptFooter,
              OperationalSettingKey.receiptShowTaxBreakdown,
              OperationalSettingKey.receiptPaperWidth,
            ]),
            _group('Sales and corrections', [
              OperationalSettingKey.salesDiscountLimitBasisPoints,
              OperationalSettingKey.salesDiscountApprovalThresholdBasisPoints,
              OperationalSettingKey.returnsApprovalThresholdMinor,
              OperationalSettingKey.returnsVoidWindowMinutes,
            ]),
            _group('Shifts', [
              OperationalSettingKey.shiftsAllowMultipleOpen,
              OperationalSettingKey.shiftsAllowSalesWithoutOpen,
              OperationalSettingKey.shiftsCashDiscrepancyApprovalThresholdMinor,
            ]),
          ],
        ),
      ),
    );
  }

  Widget _group(String title, List<OperationalSettingKey> keys) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      initiallyExpanded: title == 'Receipts',
      title: Text(title),
      children: [for (final key in keys) _tile(key)],
    );
  }

  Widget _tile(OperationalSettingKey key) {
    final setting = widget.settings[key];
    return ListTile(
      contentPadding: const EdgeInsets.only(left: AppSpacing.md),
      title: Text(key.label),
      subtitle: Text(
        '${key.description}\nCurrent: ${_valueLabel(key, setting.value)}',
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text(_originLabel(setting.origin))),
          if (_scope == SettingScope.branch &&
              setting.origin == SettingOrigin.branch)
            IconButton(
              tooltip: 'Use organization default',
              onPressed: () => _clearOverride(key),
              icon: const Icon(Icons.settings_backup_restore),
            ),
          IconButton(
            tooltip: 'Edit ${key.label.toLowerCase()}',
            onPressed: () => _edit(key, setting.value),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(OperationalSettingKey key, Object? current) async {
    final edit = await showDialog<_SettingEdit>(
      context: context,
      builder: (context) =>
          _SettingValueDialog(settingKey: key, current: current),
    );
    if (edit == null || !mounted) return;
    final result = await ref
        .read(saveOperationalSettingUseCaseProvider)
        .call(
          session: ref.read(authControllerProvider).asData?.value,
          scope: _scope,
          key: key,
          value: edit.value,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) =>
          _message('${key.label} saved for ${_scope.name} scope.'),
      onFailure: (failure) => _message(failure.message),
    );
  }

  Future<void> _clearOverride(OperationalSettingKey key) async {
    final result = await ref
        .read(saveOperationalSettingUseCaseProvider)
        .clearBranchOverride(
          session: ref.read(authControllerProvider).asData?.value,
          key: key,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => _message('${key.label} now inherits its default.'),
      onFailure: (failure) => _message(failure.message),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _SettingValueDialog extends StatefulWidget {
  const _SettingValueDialog({required this.settingKey, required this.current});

  final OperationalSettingKey settingKey;
  final Object? current;

  @override
  State<_SettingValueDialog> createState() => _SettingValueDialogState();
}

class _SettingValueDialogState extends State<_SettingValueDialog> {
  late bool _useNoThreshold = widget.current == null;
  late bool _boolean = widget.current is bool ? widget.current! as bool : false;
  late String _choice = widget.current?.toString() ?? 'per_product';
  late final TextEditingController _controller = TextEditingController(
    text: widget.current?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.settingKey.label),
    content: SizedBox(width: 460, child: _field()),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save')),
    ],
  );

  Widget _field() {
    final key = widget.settingKey;
    if (_isBoolean(key)) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_boolean ? 'Enabled' : 'Disabled'),
        subtitle: Text(key.description),
        value: _boolean,
        onChanged: (value) => setState(() => _boolean = value),
      );
    }
    if (key == OperationalSettingKey.taxBehavior) {
      return DropdownButtonFormField<String>(
        initialValue: _choice,
        decoration: const InputDecoration(labelText: 'Tax behavior'),
        items: const [
          DropdownMenuItem(value: 'per_product', child: Text('Per product')),
          DropdownMenuItem(value: 'inclusive', child: Text('Tax inclusive')),
          DropdownMenuItem(value: 'exclusive', child: Text('Tax exclusive')),
        ],
        onChanged: (value) => setState(() => _choice = value ?? _choice),
      );
    }
    if (key == OperationalSettingKey.receiptPaperWidth) {
      return DropdownButtonFormField<String>(
        initialValue: _choice,
        decoration: const InputDecoration(labelText: 'Characters per line'),
        items: const [
          DropdownMenuItem(value: '32', child: Text('32 characters')),
          DropdownMenuItem(value: '42', child: Text('42 characters')),
          DropdownMenuItem(value: '48', child: Text('48 characters')),
        ],
        onChanged: (value) => setState(() => _choice = value ?? _choice),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (key.allowsNull)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('No approval threshold'),
            value: _useNoThreshold,
            onChanged: (value) =>
                setState(() => _useNoThreshold = value ?? false),
          ),
        TextField(
          controller: _controller,
          enabled: !_useNoThreshold,
          keyboardType: _isText(key)
              ? TextInputType.text
              : TextInputType.number,
          maxLength: _isText(key)
              ? (key == OperationalSettingKey.receiptHeader ? 80 : 160)
              : null,
          decoration: InputDecoration(
            labelText: _isText(key) ? 'Text' : 'Integer value',
            helperText: key.description,
            errorText: _error,
          ),
        ),
      ],
    );
  }

  void _submit() {
    final key = widget.settingKey;
    Object? value;
    if (_isBoolean(key)) {
      value = _boolean;
    } else if (key == OperationalSettingKey.taxBehavior) {
      value = _choice;
    } else if (key == OperationalSettingKey.receiptPaperWidth) {
      value = int.parse(_choice);
    } else if (_useNoThreshold && key.allowsNull) {
      value = null;
    } else if (_isText(key)) {
      value = _controller.text.trim();
    } else {
      value = int.tryParse(_controller.text.trim());
      if (value == null) {
        setState(() => _error = 'Enter a whole number.');
        return;
      }
    }
    Navigator.pop(context, _SettingEdit(value));
  }
}

class _SettingEdit {
  const _SettingEdit(this.value);
  final Object? value;
}

bool _isBoolean(OperationalSettingKey key) => const {
  OperationalSettingKey.inventoryAllowNegativeStock,
  OperationalSettingKey.receiptShowTaxBreakdown,
  OperationalSettingKey.shiftsAllowMultipleOpen,
  OperationalSettingKey.shiftsAllowSalesWithoutOpen,
  OperationalSettingKey.salesRequireNonCashReference,
}.contains(key);

bool _isText(OperationalSettingKey key) => const {
  OperationalSettingKey.receiptHeader,
  OperationalSettingKey.receiptFooter,
}.contains(key);

String _originLabel(SettingOrigin origin) => switch (origin) {
  SettingOrigin.builtInDefault => 'BUILT-IN',
  SettingOrigin.organization => 'ORGANIZATION',
  SettingOrigin.branch => 'BRANCH',
};

String _valueLabel(OperationalSettingKey key, Object? value) {
  if (value == null) return 'No threshold';
  if (value is bool) return value ? 'Enabled' : 'Disabled';
  if (key == OperationalSettingKey.taxBehavior) {
    return switch (value) {
      'per_product' => 'Per product',
      'inclusive' => 'Tax inclusive',
      'exclusive' => 'Tax exclusive',
      _ => value.toString(),
    };
  }
  if (key == OperationalSettingKey.salesDiscountLimitBasisPoints ||
      key == OperationalSettingKey.salesDiscountApprovalThresholdBasisPoints) {
    return '${(value as int) / 100}%';
  }
  return value.toString();
}
