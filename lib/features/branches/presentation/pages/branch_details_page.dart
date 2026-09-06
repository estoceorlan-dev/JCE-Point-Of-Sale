import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../logs/domain/entities/audit_log_filter.dart';
import '../../../logs/presentation/providers/logs_providers.dart';
import '../../domain/entities/branch_profile.dart';
import '../providers/branches_providers.dart';
import '../widgets/branch_form_dialog.dart';

class BranchDetailsPage extends ConsumerStatefulWidget {
  const BranchDetailsPage({super.key, required this.branchId});
  final String branchId;

  @override
  ConsumerState<BranchDetailsPage> createState() => _BranchDetailsPageState();
}

class _BranchDetailsPageState extends ConsumerState<BranchDetailsPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeBranchAdminSessionProvider);
    if (session == null || !AppRoute.branches.canAccess(session)) {
      return const Center(
        child: Text('Branch administration access is required.'),
      );
    }
    return ref
        .watch(branchProfileProvider(widget.branchId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Branch details could not be loaded.')),
          data: (branch) {
            if (branch == null) {
              return const Center(
                child: Text('Branch not found in this organization.'),
              );
            }
            final selectable =
                branch.isActive &&
                session.activeOrganization.branchById(branch.id) != null;
            final active = session.activeBranchId == branch.id;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go(AppRoute.branches.path),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Branches'),
                    ),
                    Text(
                      branch.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Chip(label: Text(branch.isActive ? 'Active' : 'Archived')),
                    if (active) const Chip(label: Text('Current branch')),
                    OutlinedButton.icon(
                      onPressed: _busy || !branch.isActive
                          ? null
                          : () => _edit(branch),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operational profile',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final entry in <String, String?>{
                          'Code': branch.code,
                          'Timezone': branch.timezone,
                          'Address': [
                            branch.addressLineOne,
                            branch.addressLineTwo,
                            branch.city,
                            branch.province,
                            branch.postalCode,
                          ].whereType<String>().join(', '),
                          'Phone': branch.phone,
                          'Email': branch.email,
                          'Receipt display name': branch.receiptDisplayName,
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: SelectableText(
                              '${entry.key}: ${entry.value?.isNotEmpty == true ? entry.value : 'Not set'}',
                            ),
                          ),
                        Text(
                          '${branch.staffCount} cached active staff · ${branch.registerCount} registers',
                        ),
                        Text(
                          '${branch.pendingOperations} pending operations · ${branch.openShifts} open shifts',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Counts reflect this device’s cache. The server rechecks all archival guards.',
                        ),
                        if (branch.pendingOperations > 0)
                          const Text(
                            'Changes are saved locally and await synchronization.',
                          ),
                        if (branch.isActive && !selectable)
                          const Text(
                            'Synchronize, then refresh access before selecting this branch.',
                          ),
                        if (!branch.isActive)
                          const Text(
                            'Archived branches retain sales, inventory and audit history. Restore from the directory.',
                          ),
                        if (branch.openShifts > 0)
                          const Text(
                            'Open shifts must be closed before archival.',
                          ),
                        if (active)
                          const Text(
                            'The current branch cannot be archived. Select another accepted branch first.',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Related operations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Opening branch operations selects this branch as your active context.',
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final route in [
                      AppRoute.users,
                      AppRoute.registers,
                      AppRoute.inventory,
                      AppRoute.settings,
                      AppRoute.logs,
                    ])
                      if (route.canAccess(session))
                        OutlinedButton(
                          onPressed: _busy || !selectable
                              ? null
                              : () => _open(branch, route),
                          child: Text(switch (route) {
                            AppRoute.settings =>
                              'Inventory policies & receipt settings',
                            AppRoute.logs => 'Branch audit history',
                            _ => route.label,
                          }),
                        ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh access'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
  }

  Future<void> _edit(BranchProfile branch) async {
    final draft = await showDialog<BranchDraft>(
      context: context,
      builder: (_) => BranchFormDialog(branch: branch),
    );
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    final result = await ref.read(updateBranchUseCaseProvider)(
      session: ref.read(activeBranchAdminSessionProvider),
      branchId: branch.id,
      expectedVersion: branch.version,
      draft: draft,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _message(
      result.failureOrNull?.message ??
          'Profile saved locally and queued for sync.',
    );
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).refreshAccess();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _open(BranchProfile branch, AppRoute route) async {
    setState(() => _busy = true);
    await ref
        .read(authControllerProvider.notifier)
        .selectActiveBranch(
          organizationId: branch.organizationId,
          branchId: branch.id,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    final session = ref.read(activeBranchAdminSessionProvider);
    if (session == null ||
        session.activeBranchId != branch.id ||
        !route.canAccess(session)) {
      _message('Refresh access and verify your permissions for this branch.');
      return;
    }
    if (route == AppRoute.logs) {
      ref.read(auditLogFilterProvider.notifier).state = AuditLogFilter(
        branchId: branch.id,
      );
    }
    context.go(
      route == AppRoute.users
          ? '${route.path}?branchId=${Uri.encodeQueryComponent(branch.id)}'
          : route.path,
    );
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
