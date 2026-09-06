import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class SyncConflictPanel extends ConsumerWidget {
  const SyncConflictPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(unresolvedSyncConflictsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_problem_outlined),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Sync conflicts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                conflicts.when(
                  data: (rows) => Text('${rows.length} unresolved'),
                  error: (_, _) => const Text('Unavailable'),
                  loading: () => const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Review remote rejections before choosing which version wins.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            conflicts.when(
              data: (rows) => rows.isEmpty
                  ? const Text('No conflicts require attention.')
                  : Column(
                      children: [
                        for (final conflict in rows)
                          _ConflictTile(conflict: conflict),
                      ],
                    ),
              error: (error, _) => Text('Unable to load conflicts: $error'),
              loading: () => const LinearProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictTile extends ConsumerWidget {
  const _ConflictTile({required this.conflict});

  final SyncConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.warning_amber_rounded),
      title: Text('${conflict.entityType} • ${conflict.entityId}'),
      subtitle: Text(conflict.reason),
      trailing: Wrap(
        spacing: AppSpacing.sm,
        children: [
          OutlinedButton(
            onPressed: () async {
              final result = await ref
                  .read(syncStateProvider.notifier)
                  .acceptRemote(conflict);
              if (context.mounted && result.failureOrNull != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.failureOrNull!.message)),
                );
              }
            },
            child: const Text('Accept remote'),
          ),
          FilledButton(
            onPressed: () =>
                ref.read(syncStateProvider.notifier).retryConflict(conflict),
            child: const Text('Retry local'),
          ),
        ],
      ),
    );
  }
}
