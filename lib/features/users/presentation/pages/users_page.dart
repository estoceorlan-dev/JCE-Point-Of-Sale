import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../shared/models/user_account_status.dart';
import '../../../../shared/models/permission.dart';
import '../../../branches/domain/entities/branch_profile.dart';
import '../../../branches/presentation/providers/branches_providers.dart';
import '../../domain/entities/staff_account.dart';
import '../providers/users_providers.dart';
import '../widgets/role_form_dialog.dart';
import '../widgets/staff_form_dialog.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key, this.branchId});
  final String? branchId;

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  UserAccountStatus? _status;
  var _includeArchivedRoles = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(activeUserAdminSessionProvider);
    _tabs = TabController(
      length: 2,
      initialIndex:
          session?.canOrganizationWide(AppPermission.manageUsers) == true
          ? 0
          : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeUserAdminSessionProvider);
    final canManageStaff =
        session?.canOrganizationWide(AppPermission.manageUsers) == true;
    final canManageRoles =
        session?.canOrganizationWide(AppPermission.manageRoles) == true;
    final staff = canManageStaff
        ? ref.watch(staffDirectoryProvider)
        : const AsyncData<List<StaffAccount>>([]);
    final roles = ref.watch(roleDirectoryProvider(_includeArchivedRoles));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff & Access',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Invite staff, control account status, branch assignments, roles, and permissions.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: _tabs,
                builder: (context, _) => FilledButton.icon(
                  onPressed:
                      _busy ||
                          (_tabs.index == 0 ? !canManageStaff : !canManageRoles)
                      ? null
                      : _tabs.index == 0
                      ? () => _openStaffDialog()
                      : () => _openRoleDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(_tabs.index == 0 ? 'Invite staff' : 'New role'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Staff directory'),
              Tab(text: 'Roles'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              canManageStaff
                  ? _staffTab(staff)
                  : const Center(
                      child: Text(
                        'Staff management requires organization-wide users.manage access.',
                      ),
                    ),
              _rolesTab(roles),
            ],
          ),
        ),
      ],
    );
  }

  Widget _staffTab(AsyncValue<List<StaffAccount>> value) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        if (widget.branchId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Showing staff assigned to this branch, including organization-wide roles.',
            ),
          ),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search name or email',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<UserAccountStatus?>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  for (final status in UserAccountStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(_label(status.name)),
                    ),
                ],
                onChanged: (value) => setState(() => _status = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorCard(message: '$error'),
          data: (allStaff) {
            final needle = _searchController.text.trim().toLowerCase();
            final staff = allStaff.where((item) {
              final matchesText =
                  needle.isEmpty ||
                  item.displayName.toLowerCase().contains(needle) ||
                  item.email.toLowerCase().contains(needle);
              final matchesBranch =
                  widget.branchId == null ||
                  item.assignments.any(
                    (assignment) =>
                        assignment.branchId == null ||
                        assignment.branchId == widget.branchId,
                  );
              return matchesText &&
                  matchesBranch &&
                  (_status == null || item.status == _status);
            }).toList();
            if (staff.isEmpty) {
              return const _EmptyCard(
                icon: Icons.badge_outlined,
                message: 'No staff accounts match these filters.',
              );
            }
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < staff.length; index++) ...[
                    _staffTile(staff[index]),
                    if (index != staff.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _staffTile(StaffAccount account) {
    final assignments = account.assignments
        .map(
          (item) => item.branchId == null
              ? '${item.roleName} · Organization'
              : '${item.roleName} · ${item.branchName ?? item.branchId}',
        )
        .join(', ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: CircleAvatar(child: Text(_initials(account.displayName))),
      title: Text(account.displayName),
      subtitle: Text(
        [account.email, if (assignments.isNotEmpty) assignments].join('\n'),
      ),
      isThreeLine: assignments.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusChip(status: account.status),
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openStaffDialog(account);
                case 'active':
                  _setStaffStatus(account, UserAccountStatus.active);
                case 'suspended':
                  _setStaffStatus(account, UserAccountStatus.suspended);
                case 'disabled':
                  _setStaffStatus(account, UserAccountStatus.disabled);
                case 'invite':
                  _copyInviteLink(account);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit account & access'),
              ),
              if (account.status == UserAccountStatus.invited)
                const PopupMenuItem(
                  value: 'invite',
                  child: Text('Copy invite link'),
                ),
              if (account.status != UserAccountStatus.active)
                const PopupMenuItem(value: 'active', child: Text('Activate')),
              if (account.status == UserAccountStatus.active)
                const PopupMenuItem(value: 'suspended', child: Text('Suspend')),
              if (account.status != UserAccountStatus.disabled)
                const PopupMenuItem(value: 'disabled', child: Text('Disable')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rolesTab(AsyncValue<List<RoleDefinition>> value) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            selected: _includeArchivedRoles,
            label: const Text('Show archived roles'),
            onSelected: (value) =>
                setState(() => _includeArchivedRoles = value),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorCard(message: '$error'),
          data: (roles) => roles.isEmpty
              ? const _EmptyCard(
                  icon: Icons.admin_panel_settings_outlined,
                  message: 'Create a role to assign permissions to staff.',
                )
              : Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var index = 0; index < roles.length; index++) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          leading: Icon(
                            roles[index].isActive
                                ? Icons.admin_panel_settings_outlined
                                : Icons.archive_outlined,
                          ),
                          title: Text(roles[index].name),
                          subtitle: Text(
                            '${roles[index].code} · ${roles[index].permissions.length} permissions · ${roles[index].assignmentCount} assignments',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!roles[index].isActive)
                                const Chip(label: Text('ARCHIVED')),
                              PopupMenuButton<String>(
                                enabled:
                                    !_busy &&
                                    ref
                                            .watch(
                                              activeUserAdminSessionProvider,
                                            )
                                            ?.canOrganizationWide(
                                              AppPermission.manageRoles,
                                            ) ==
                                        true,
                                onSelected: (action) => action == 'edit'
                                    ? _openRoleDialog(roles[index])
                                    : _setRoleArchived(
                                        roles[index],
                                        action == 'archive',
                                      ),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit role'),
                                  ),
                                  PopupMenuItem(
                                    value: roles[index].isActive
                                        ? 'archive'
                                        : 'restore',
                                    child: Text(
                                      roles[index].isActive
                                          ? 'Archive'
                                          : 'Restore',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (index != roles.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _openStaffDialog([StaffAccount? account]) async {
    final values = await Future.wait([
      ref.read(roleDirectoryProvider(false).future),
      ref.read(branchDirectoryProvider(const BranchQuery()).future),
    ]);
    if (!mounted) return;
    final roles = values[0] as List<RoleDefinition>;
    final branches = values[1] as List<BranchProfile>;
    final result = await showDialog<StaffDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          StaffFormDialog(account: account, roles: roles, branches: branches),
    );
    if (result == null) return;
    final session = ref.read(activeUserAdminSessionProvider);
    final useCase = ref.read(manageStaffUseCaseProvider);
    if (account == null) {
      await _run(() => useCase.invite(session: session, draft: result));
      return;
    }
    final profileResult = await useCase.update(
      session: session,
      account: account,
      displayName: result.displayName,
      email: result.email,
    );
    if (!mounted || profileResult.isFailure) {
      if (profileResult.failureOrNull case final failure?) {
        _showFailure(failure);
      }
      return;
    }
    await _run(
      () => useCase.replaceAssignments(
        session: session,
        userId: account.id,
        assignments: result.assignments,
      ),
    );
  }

  Future<void> _openRoleDialog([RoleDefinition? role]) async {
    final draft = await showDialog<RoleDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RoleFormDialog(role: role),
    );
    if (draft == null) return;
    final useCase = ref.read(manageRolesUseCaseProvider);
    final session = ref.read(activeUserAdminSessionProvider);
    await _run(
      () => role == null
          ? useCase.create(session: session, draft: draft)
          : useCase.update(session: session, role: role, draft: draft),
    );
  }

  Future<void> _setStaffStatus(
    StaffAccount account,
    UserAccountStatus status,
  ) async {
    await _run(
      () => ref
          .read(manageStaffUseCaseProvider)
          .setStatus(
            session: ref.read(activeUserAdminSessionProvider),
            account: account,
            status: status,
          ),
    );
  }

  Future<void> _copyInviteLink(StaffAccount account) async {
    setState(() => _busy = true);
    await ref.read(syncStateProvider.notifier).synchronize();
    final result = await ref
        .read(staffInvitationServiceProvider)
        .generateLink(
          organizationId: account.organizationId,
          userId: account.id,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      onSuccess: (url) async {
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invite link copied. It was not stored locally.'),
            ),
          );
        }
      },
      onFailure: _showFailure,
    );
  }

  Future<void> _setRoleArchived(RoleDefinition role, bool archived) async {
    await _run(
      () => ref
          .read(manageRolesUseCaseProvider)
          .setArchived(
            session: ref.read(activeUserAdminSessionProvider),
            role: role,
            archived: archived,
          ),
    );
  }

  Future<void> _run(
    Future<Result<dynamic, Failure>> Function() operation,
  ) async {
    setState(() => _busy = true);
    final result = await operation();
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved locally and queued for sync.')),
      ),
      onFailure: _showFailure,
    );
  }

  void _showFailure(Failure failure) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final UserAccountStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      UserAccountStatus.active => Colors.green,
      UserAccountStatus.invited => Colors.blue,
      UserAccountStatus.suspended => Colors.orange,
      UserAccountStatus.disabled => Colors.red,
    };
    return Chip(
      avatar: Icon(Icons.circle, color: color, size: 10),
      label: Text(status.name.toUpperCase()),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(message),
    ),
  );
}

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  return words
      .take(2)
      .where((word) => word.isNotEmpty)
      .map((word) => word[0])
      .join()
      .toUpperCase();
}

String _label(String value) => value.isEmpty
    ? value
    : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
