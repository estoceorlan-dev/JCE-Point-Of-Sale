import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../branches/presentation/providers/branches_providers.dart';
import '../widgets/sync_conflict_panel.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    if (session == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Branch identity and operational preferences.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active branch',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(session.activeBranch.branch.name),
                  subtitle: Text(
                    '${session.activeOrganization.organization.name} • '
                    '${session.activeBranch.branch.code}',
                  ),
                  trailing: OutlinedButton.icon(
                    onPressed: () => _editBranchName(context, ref),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit name'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SyncConflictPanel(),
      ],
    );
  }

  Future<void> _editBranchName(BuildContext context, WidgetRef ref) async {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      return;
    }
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
          decoration: const InputDecoration(
            labelText: 'Branch name or label',
            hintText: 'Example: JCE Main Branch',
          ),
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
    if (name == null || !context.mounted) {
      return;
    }

    final result = await ref
        .read(updateBranchNameUseCaseProvider)
        .call(session: session, name: name);
    if (!context.mounted) {
      return;
    }
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
