import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/feature_flag.dart';
import '../../domain/entities/operational_setting.dart';
import '../providers/settings_providers.dart';

class FeatureFlagsPanel extends ConsumerWidget {
  const FeatureFlagsPanel({required this.flags, super.key});

  final List<FeatureFlag> flags;

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
                      'Feature flags',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Controlled rollout switches with organization and branch scope.',
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add flag'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (flags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: Text('No feature flags configured.')),
            )
          else
            for (final flag in flags)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(flag.key),
                subtitle: Text(
                  '${flag.scope.name} scope · version ${flag.version}',
                ),
                value: flag.isEnabled,
                onChanged: (value) => _save(
                  context,
                  ref,
                  key: flag.key,
                  enabled: value,
                  scope: flag.scope,
                ),
              ),
        ],
      ),
    ),
  );

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var scope = SettingScope.branch;
    final value = await showDialog<({String key, SettingScope scope})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add feature flag'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: 'Flag key',
                    hintText: 'loyalty.redemption_enabled',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<SettingScope>(
                  initialValue: scope,
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
                  onChanged: (value) => setState(() => scope = value ?? scope),
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
              onPressed: () =>
                  Navigator.pop(context, (key: controller.text, scope: scope)),
              child: const Text('Add disabled'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    await _save(
      context,
      ref,
      key: value.key,
      enabled: false,
      scope: value.scope,
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required bool enabled,
    required SettingScope scope,
  }) async {
    final result = await ref
        .read(saveFeatureFlagUseCaseProvider)
        .call(
          session: ref.read(authControllerProvider).asData?.value,
          key: key,
          isEnabled: enabled,
          scope: scope,
        );
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Feature flag saved.'))),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}
