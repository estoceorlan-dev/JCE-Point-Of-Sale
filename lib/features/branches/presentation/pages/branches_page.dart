import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_route.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../domain/entities/branch_profile.dart';
import '../providers/branches_providers.dart';
import '../widgets/branch_form_dialog.dart';

class BranchesPage extends ConsumerStatefulWidget {
  const BranchesPage({super.key});

  @override
  ConsumerState<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends ConsumerState<BranchesPage> {
  String _search = '';
  bool _includeArchived = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final query = BranchQuery(
      search: _search,
      includeArchived: _includeArchived,
    );
    final branches = ref.watch(branchDirectoryProvider(query));
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
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
                      'Branches',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Manage branch profiles and operational availability.',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _submitting ? null : () => _save(),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Add branch'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search branch name, code, or city',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilterChip(
                selected: _includeArchived,
                onSelected: (value) => setState(() => _includeArchived = value),
                label: const Text('Show archived'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: branches.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Branches could not be loaded: $error')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No branches match this view.'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => _BranchCard(
                        branch: items[index],
                        busy: _submitting,
                        onEdit: () => _save(items[index]),
                        onArchived: () => _setArchived(items[index]),
                        onDetails: () => context.go(
                          '${AppRoute.branches.path}/${Uri.encodeComponent(items[index].id)}',
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save([BranchProfile? branch]) async {
    final draft = await showDialog<BranchDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BranchFormDialog(branch: branch),
    );
    if (draft == null || !mounted) return;
    setState(() => _submitting = true);
    final session = ref.read(activeBranchAdminSessionProvider);
    final result = branch == null
        ? await ref.read(createBranchUseCaseProvider)(
            session: session,
            draft: draft,
          )
        : await ref.read(updateBranchUseCaseProvider)(
            session: session,
            branchId: branch.id,
            expectedVersion: branch.version,
            draft: draft,
          );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      onSuccess: (_) => _message(
        branch == null
            ? 'Branch added. Synchronize to activate access.'
            : 'Branch updated.',
      ),
      onFailure: (failure) => _message(failure.message),
    );
  }

  Future<void> _setArchived(BranchProfile branch) async {
    final archived = branch.isActive;
    if (archived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const AppConfirmationDialog(
          title: 'Archive branch?',
          message:
              'Historical sales and inventory remain available. New activity will be blocked.',
          confirmLabel: 'Archive branch',
          destructive: true,
          icon: Icons.archive_outlined,
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _submitting = true);
    final result = await ref.read(setBranchArchivedUseCaseProvider)(
      session: ref.read(activeBranchAdminSessionProvider),
      branchId: branch.id,
      archived: archived,
      expectedVersion: branch.version,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      onSuccess: (_) =>
          _message(archived ? 'Branch archived.' : 'Branch restored.'),
      onFailure: (failure) => _message(failure.message),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.busy,
    required this.onEdit,
    required this.onArchived,
    required this.onDetails,
  });

  final BranchProfile branch;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onArchived;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final location = [
      branch.city,
      branch.province,
    ].whereType<String>().where((value) => value.isNotEmpty).join(', ');
    return Card(
      child: InkWell(
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(branch.name)),
                  Chip(label: Text(branch.isActive ? 'ACTIVE' : 'ARCHIVED')),
                ],
              ),
              Text(
                [
                  branch.code,
                  branch.timezone,
                  if (location.isNotEmpty) location,
                  if (branch.phone != null) branch.phone!,
                  '${branch.staffCount} staff · ${branch.registerCount} registers',
                  if (branch.pendingOperations > 0)
                    '${branch.pendingOperations} pending changes',
                  if (branch.openShifts > 0) '${branch.openShifts} open shifts',
                ].join(' · '),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  IconButton(
                    tooltip: 'Edit branch',
                    onPressed: busy || !branch.isActive ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: branch.isActive
                        ? 'Archive branch'
                        : 'Restore branch',
                    onPressed: busy ? null : onArchived,
                    icon: Icon(
                      branch.isActive ? Icons.archive_outlined : Icons.restore,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
