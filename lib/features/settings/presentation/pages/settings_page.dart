import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../branches/presentation/providers/branches_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/feature_flags_panel.dart';
import '../widgets/operational_settings_panel.dart';
import '../widgets/reason_codes_panel.dart';
import '../widgets/sync_conflict_panel.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    if (session == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.symmetric(
          horizontal: constraints.maxWidth < AppBreakpoints.compact
              ? AppSpacing.lg
              : AppSpacing.xxl,
          vertical: AppSpacing.xxl,
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operational settings',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Organization defaults and branch overrides are cached locally for offline operation.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                _ActiveBranchCard(
                  organizationName:
                      session.activeOrganization.organization.name,
                  branchName: session.activeBranch.branch.name,
                  branchCode: session.activeBranch.branch.code,
                  onEdit: () => _editBranchName(context, ref),
                ),
                const SizedBox(height: AppSpacing.xl),
                ref
                    .watch(operationalSettingsProvider)
                    .when(
                      loading: _loading,
                      error: (error, _) => _error(error.toString()),
                      data: (settings) =>
                          OperationalSettingsPanel(settings: settings),
                    ),
                const SizedBox(height: AppSpacing.xl),
                ref
                    .watch(reasonCodesProvider)
                    .when(
                      loading: _loading,
                      error: (error, _) => _error(error.toString()),
                      data: (codes) => ReasonCodesPanel(codes: codes),
                    ),
                const SizedBox(height: AppSpacing.xl),
                ref
                    .watch(featureFlagsProvider)
                    .when(
                      loading: _loading,
                      error: (error, _) => _error(error.toString()),
                      data: (flags) => FeatureFlagsPanel(flags: flags),
                    ),
                const SizedBox(height: AppSpacing.xl),
                const SyncConflictPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  Widget _error(String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message),
    ),
  );

  Future<void> _editBranchName(BuildContext context, WidgetRef ref) async {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) return;
    final controller = TextEditingController(
      text: session.activeBranch.branch.name,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit branch name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
          decoration: const InputDecoration(labelText: 'Branch name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    final result = await ref
        .read(updateBranchNameUseCaseProvider)
        .call(session: session, name: name);
    if (!context.mounted) return;
    if (result case FailureResult(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    await ref.read(authControllerProvider.notifier).refreshAccess();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Branch name updated.')));
    }
  }
}

class _ActiveBranchCard extends StatelessWidget {
  const _ActiveBranchCard({
    required this.organizationName,
    required this.branchName,
    required this.branchCode,
    required this.onEdit,
  });

  final String organizationName;
  final String branchName;
  final String branchCode;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active branch', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_outlined),
            title: Text(branchName),
            subtitle: Text('$organizationName · $branchCode'),
            trailing: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit name'),
            ),
          ),
        ],
      ),
    ),
  );
}
