import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/models/permission.dart';
import '../../domain/entities/sale.dart';
import '../providers/pos_providers.dart';
import '../widgets/correction_policy_dialog.dart';
import '../widgets/sale_details_dialog.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  Timer? _searchDebounce;
  String _search = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(recentSalesSearchProvider(_search));
    final canManagePolicy =
        ref
            .watch(activePosSessionProvider)
            ?.can(AppPermission.manageSettings) ??
        false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < AppBreakpoints.compact
            ? AppSpacing.lg
            : AppSpacing.xxl;
        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sales transactions',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ),
                        if (canManagePolicy)
                          OutlinedButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) =>
                                  const CorrectionPolicyDialog(),
                            ),
                            icon: const Icon(Icons.policy_outlined),
                            label: const Text('Correction policy'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Recent branch receipts remain readable from their saved product and price snapshots.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Find a receipt',
                        hintText: 'Canonical or offline receipt number',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 250),
                          () {
                            if (mounted) setState(() => _search = value.trim());
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    sales.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xxl),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text('Sales could not be loaded: $error'),
                        ),
                      ),
                      data: (items) => _SalesList(
                        sales: items,
                        onOpen: (sale) => showDialog<void>(
                          context: context,
                          builder: (context) => SaleDetailsDialog(sale: sale),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({required this.sales, required this.onOpen});

  final List<SaleRecord> sales;
  final ValueChanged<SaleRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: Text('No completed sales on this branch yet.')),
        ),
      );
    }
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sales.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final sale = sales[index];
          return ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(sale.receiptNumber),
            subtitle: Text(
              [
                sale.registerName,
                sale.completedAt.toLocal().toString(),
                '${sale.items.length} item(s)',
                if (sale.receiptAliases.isNotEmpty)
                  'Offline: ${sale.receiptAliases.join(', ')}',
              ].join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(label: Text(sale.status.label)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  Formatters.currencyMinor(sale.totalMinor),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => onOpen(sale),
          );
        },
      ),
    );
  }
}
