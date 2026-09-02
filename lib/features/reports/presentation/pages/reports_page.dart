import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/services/report_value_formatter.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/report_filter_options.dart';
import '../providers/reports_providers.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(reportFilterStateProvider);
    final options = ref
        .watch(reportFilterOptionsProvider)
        .asData
        ?.value
        .valueOrNull;
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
                Text('Reports', style: theme.textTheme.headlineLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Offline operational reporting from synchronized local data.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                _ReportFilters(filter: filter, options: options),
                const SizedBox(height: AppSpacing.xl),
                ref
                    .watch(reportDatasetProvider)
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
                        onSuccess: (dataset) =>
                            _ReportResults(dataset: dataset, filter: filter),
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
}

class _ReportFilters extends ConsumerWidget {
  const _ReportFilters({required this.filter, required this.options});

  final ReportFilterState filter;
  final ReportFilterOptions? options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final permittedIds = permittedReportBranchIds(ref).toSet();
    final branches =
        session?.activeOrganization.branches
            .where((access) => permittedIds.contains(access.branch.id))
            .toList(growable: false) ??
        const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _field(
              DropdownButtonFormField<ReportType>(
                initialValue: ref.watch(reportTypeProvider),
                decoration: const InputDecoration(labelText: 'Report'),
                items: [
                  for (final type in ReportType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(reportTypeProvider.notifier).state = value;
                  _update(ref, filter.copyWith(page: 1));
                },
              ),
              width: 280,
            ),
            _field(
              DropdownButtonFormField<String>(
                initialValue:
                    branches.any(
                      (access) => access.branch.id == filter.branchId,
                    )
                    ? filter.branchId
                    : null,
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
                    _update(ref, filter.copyWith(branchId: value, page: 1));
                  }
                },
              ),
            ),
            _DateButton(
              label: 'From',
              value: filter.fromDate,
              onChanged: (value) =>
                  _update(ref, filter.copyWith(fromDate: value, page: 1)),
            ),
            _DateButton(
              label: 'To',
              value: filter.toDate,
              onChanged: (value) =>
                  _update(ref, filter.copyWith(toDate: value, page: 1)),
            ),
            _optionDropdown(
              label: 'Product',
              value: filter.productId,
              options: options?.products ?? const [],
              onChanged: (value) =>
                  _update(ref, filter.copyWith(productId: value, page: 1)),
            ),
            _optionDropdown(
              label: 'Category',
              value: filter.categoryId,
              options: options?.categories ?? const [],
              onChanged: (value) =>
                  _update(ref, filter.copyWith(categoryId: value, page: 1)),
            ),
            _optionDropdown(
              label: 'User',
              value: filter.userId,
              options: options?.users ?? const [],
              onChanged: (value) =>
                  _update(ref, filter.copyWith(userId: value, page: 1)),
            ),
            _field(
              DropdownButtonFormField<String?>(
                initialValue: filter.paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All methods')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'e_wallet', child: Text('E-wallet')),
                ],
                onChanged: (value) => _update(
                  ref,
                  filter.copyWith(paymentMethod: value, page: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionDropdown({
    required String label,
    required String? value,
    required List<ReportFilterOption> options,
    required ValueChanged<String?> onChanged,
  }) {
    return _field(
      DropdownButtonFormField<String?>(
        initialValue: options.any((option) => option.id == value)
            ? value
            : null,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text('All ${label.toLowerCase()}s'),
          ),
          for (final option in options)
            DropdownMenuItem(value: option.id, child: Text(option.label)),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(Widget child, {double width = 220}) =>
      SizedBox(width: width, child: child);

  void _update(WidgetRef ref, ReportFilterState value) {
    ref.read(reportFilterStateProvider.notifier).state = value;
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text('$label ${_date(value)}'),
        onPressed: () async {
          final selected = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 366)),
            initialDate: value,
          );
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

class _ReportResults extends ConsumerWidget {
  const _ReportResults({required this.dataset, required this.filter});

  final ReportDataset dataset;
  final ReportFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dataset.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(dataset.definition),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => _copyCsv(context, ref),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('CSV'),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _showPrintable(context, ref),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Printable'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (dataset.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: Text('No records match these filters.')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    for (final column in dataset.columns)
                      DataColumn(label: Text(column.label)),
                  ],
                  rows: [
                    for (final row in dataset.rows)
                      DataRow(
                        cells: [
                          for (final column in dataset.columns)
                            DataCell(
                              Text(
                                ReportValueFormatter.display(
                                  row[column.key],
                                  column.format,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('${dataset.totalRows} rows'),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: filter.page <= 1
                      ? null
                      : () => _setPage(ref, filter.page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Page ${dataset.page} of ${dataset.totalPages}'),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: filter.page >= dataset.totalPages
                      ? null
                      : () => _setPage(ref, filter.page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCsv(BuildContext context, WidgetRef ref) async {
    final reportFilter = _domainFilter(ref);
    if (reportFilter == null) return;
    final csv = ref
        .read(csvReportExporterProvider)
        .export(dataset: dataset, filter: reportFilter);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filtered report CSV copied.')),
    );
  }

  void _showPrintable(BuildContext context, WidgetRef ref) {
    final reportFilter = _domainFilter(ref);
    if (reportFilter == null) return;
    final document = ref
        .read(printableReportBuilderProvider)
        .export(dataset: dataset, filter: reportFilter);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.title),
        content: SizedBox(
          width: 900,
          child: SingleChildScrollView(
            child: SelectableText(
              '${document.period}\n${document.definition}\n\n'
              '${document.columns.join(' | ')}\n'
              '${document.rows.map((row) => row.join(' | ')).join('\n')}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  ReportFilter? _domainFilter(WidgetRef ref) {
    final session = ref.read(authControllerProvider).asData?.value;
    final branch = session?.activeOrganization.branchById(filter.branchId);
    if (branch == null) return null;
    final range = ref
        .read(reportsBusinessDayProvider)
        .range(
          fromDate: filter.fromDate,
          toDate: filter.toDate,
          timezoneName: branch.branch.timezone,
        );
    return filter.toFilter(start: range.start, end: range.endExclusive);
  }

  void _setPage(WidgetRef ref, int page) {
    ref.read(reportFilterStateProvider.notifier).state = filter.copyWith(
      page: page,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message),
    ),
  );
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
