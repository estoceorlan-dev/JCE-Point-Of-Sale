import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/audit_log_filter.dart';
import '../providers/logs_providers.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _searchController = TextEditingController();
  final _actorController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _actorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(auditLogFilterProvider);
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
                Text('Audit logs', style: theme.textTheme.headlineLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Append-only operational history, available from the local cache while offline.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                _filters(filter),
                const SizedBox(height: AppSpacing.xl),
                ref
                    .watch(auditTrailProvider)
                    .when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xxl),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) =>
                          _ErrorCard(message: error.toString()),
                      data: (result) => result.fold(
                        onSuccess: (entries) => _AuditResults(
                          entries: entries,
                          filter: filter,
                          onFilterChanged: _setFilter,
                        ),
                        onFailure: (failure) =>
                            _ErrorCard(message: failure.message),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(AuditLogFilter filter) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final branches =
        session?.activeOrganization.branches.where(
          (access) => session.activeOrganization
              .permissionsFor(access.branch.id)
              .contains(AppPermission.viewAuditLogs),
        ) ??
        const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  hintText: 'Entity, ID, operation, actor',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    _setFilter(filter.copyWith(search: value, page: 1)),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: filter.branchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: [
                  for (final access in branches)
                    DropdownMenuItem(
                      value: access.branch.id,
                      child: Text(access.branch.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _setFilter(filter.copyWith(branchId: value, page: 1));
                  }
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<AuditActionType?>(
                isExpanded: true,
                initialValue: filter.actionType,
                decoration: const InputDecoration(labelText: 'Action'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All actions'),
                  ),
                  for (final action in AuditActionType.values)
                    DropdownMenuItem(
                      value: action,
                      child: Text(_humanize(action.name)),
                    ),
                ],
                onChanged: (value) => _setFilter(
                  value == null
                      ? filter.copyWith(clearActionType: true, page: 1)
                      : filter.copyWith(actionType: value, page: 1),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _actorController,
                decoration: const InputDecoration(
                  labelText: 'Actor user ID',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                onChanged: (value) => _setFilter(
                  AuditLogFilter(
                    branchId: filter.branchId,
                    actorUserId: value.trim().isEmpty ? null : value.trim(),
                    actionType: filter.actionType,
                    entityName: filter.entityName,
                    search: filter.search,
                    from: filter.from,
                    to: filter.to,
                    pageSize: filter.pageSize,
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: filter.from == null || filter.to == null
                      ? null
                      : DateTimeRange(start: filter.from!, end: filter.to!),
                );
                if (range != null) {
                  _setFilter(
                    filter.copyWith(
                      from: range.start,
                      to: range.end.add(const Duration(days: 1)),
                      page: 1,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                filter.from == null
                    ? 'Any date'
                    : '${_shortDate(filter.from!)} – ${_shortDate(filter.to!.subtract(const Duration(days: 1)))}',
              ),
            ),
            if (filter.from != null ||
                filter.actionType != null ||
                filter.search.isNotEmpty ||
                filter.actorUserId != null)
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _actorController.clear();
                  _setFilter(AuditLogFilter(branchId: filter.branchId));
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
          ],
        ),
      ),
    );
  }

  void _setFilter(AuditLogFilter value) {
    ref.read(auditLogFilterProvider.notifier).state = value;
  }
}

class _AuditResults extends StatelessWidget {
  const _AuditResults({
    required this.entries,
    required this.filter,
    required this.onFilterChanged,
  });

  final List<AuditLogEntry> entries;
  final AuditLogFilter filter;
  final ValueChanged<AuditLogFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: Text('No audit events match these filters.')),
        ),
      );
    }
    return Column(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                _AuditTile(entry: entries[index]),
                if (index != entries.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Page ${filter.page}'),
            const SizedBox(width: AppSpacing.md),
            IconButton(
              tooltip: 'Previous page',
              onPressed: filter.page == 1
                  ? null
                  : () =>
                        onFilterChanged(filter.copyWith(page: filter.page - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: entries.length < filter.pageSize
                  ? null
                  : () =>
                        onFilterChanged(filter.copyWith(page: filter.page + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: CircleAvatar(child: Icon(_icon(entry.actionType), size: 20)),
      title: Text(
        '${_humanize(entry.actionType.name)} · ${_humanize(entry.entityName)}',
      ),
      subtitle: Text(
        'Actor ${entry.actorUserId} · ${_timestamp(entry.createdAt)}\n'
        'Entity ${entry.entityId}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => _AuditDetailsDialog(entry: entry),
      ),
    );
  }
}

class _AuditDetailsDialog extends StatelessWidget {
  const _AuditDetailsDialog({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final metadata = const JsonEncoder.withIndent('  ').convert(entry.metadata);
    return AlertDialog(
      title: Text('${_humanize(entry.actionType.name)} event'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('Timestamp', _timestamp(entry.createdAt)),
              _detail('Actor', entry.actorUserId),
              _detail('Device', entry.deviceId ?? 'Not recorded'),
              _detail('Branch', entry.branchId ?? 'Organization-wide'),
              _detail('Entity', '${entry.entityName} / ${entry.entityId}'),
              _detail('Operation', entry.operationId ?? 'Local event'),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Safe metadata',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: SelectableText(
                  metadata,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: SelectableText('$label: $value'),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}

IconData _icon(AuditActionType action) => switch (action) {
  AuditActionType.login ||
  AuditActionType.logout ||
  AuditActionType.loginFailed => Icons.security_outlined,
  AuditActionType.settingChange ||
  AuditActionType.roleChange => Icons.admin_panel_settings_outlined,
  AuditActionType.sale => Icons.point_of_sale_outlined,
  AuditActionType.transfer => Icons.swap_horiz_outlined,
  AuditActionType.sync => Icons.sync_outlined,
  _ => Icons.history_outlined,
};

String _humanize(String value) => value
    .replaceAll('_', ' ')
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    )
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _shortDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _timestamp(DateTime value) {
  final local = value.toLocal();
  return '${_shortDate(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}';
}
