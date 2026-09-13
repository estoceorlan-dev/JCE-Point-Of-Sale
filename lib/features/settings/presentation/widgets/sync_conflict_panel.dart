import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart' hide Register;
import '../../../../core/database/database_provider.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../shifts/domain/entities/register.dart';
import '../../../shifts/presentation/providers/shift_providers.dart';

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
    final session = ref.watch(authControllerProvider).asData?.value;
    final canResolveClaim =
        conflict.entityType == 'register_claim' &&
        (session?.can(AppPermission.manageRegisters) ?? false);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.warning_amber_rounded),
      title: Text('${conflict.entityType} • ${conflict.entityId}'),
      subtitle: Text(conflict.reason),
      trailing: Wrap(
        spacing: AppSpacing.sm,
        children: [
          if (canResolveClaim)
            FilledButton(
              onPressed: () => _resolveRegisterClaim(context, ref),
              child: const Text('Reassign'),
            ),
          if (!canResolveClaim)
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
          if (!canResolveClaim)
            FilledButton(
              onPressed: () =>
                  ref.read(syncStateProvider.notifier).retryConflict(conflict),
              child: const Text('Retry local'),
            ),
        ],
      ),
    );
  }

  Future<void> _resolveRegisterClaim(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) return;
    final database = ref.read(appDatabaseProvider);
    final claim = await (database.select(
      database.registerClaims,
    )..where((row) => row.id.equals(conflict.entityId))).getSingleOrNull();
    if (claim == null || !context.mounted) return;
    final registers = await ref.read(registersProvider.future);
    if (!context.mounted) return;
    final available = registers
        .where(
          (register) =>
              register.branchId == claim.branchId &&
              register.isActive &&
              register.assignedDeviceId == null,
        )
        .toList(growable: false);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an unclaimed register in this branch first.'),
        ),
      );
      return;
    }
    final target = await showDialog<Register>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Reassign terminal records'),
        children: [
          for (final register in available)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, register),
              child: ListTile(
                title: Text(register.name),
                subtitle: Text(register.code),
              ),
            ),
        ],
      ),
    );
    if (target == null || !context.mounted) return;
    final businessContext = BusinessContext(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      actorUserId: session.activeOrganization.appUserId,
    );
    final result = await ref
        .read(registerClaimRepositoryProvider)
        .resolve(
          context: businessContext,
          claimId: claim.id,
          targetRegisterId: target.id,
        );
    if (result.isSuccess) {
      await ref.read(syncStateProvider.notifier).synchronize();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failureOrNull?.message ??
              'Register reassignment queued and will rebase the losing terminal.',
        ),
      ),
    );
  }
}
