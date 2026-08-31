import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/stock_transfer.dart';
import '../providers/transfers_providers.dart';
import '../widgets/create_transfer_dialog.dart';
import '../widgets/transfer_details_dialog.dart';
import '../widgets/transfer_policy_dialog.dart';

class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(stockTransfersProvider);
    final session = ref.watch(activeTransferSessionProvider);
    final canCreate = session?.can(AppPermission.manageInventory) ?? false;
    final canConfigure = session?.can(AppPermission.manageSettings) ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < AppBreakpoints.compact
            ? AppSpacing.lg
            : AppSpacing.xxl;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 560,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stock transfers',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Branch custody, approval, shipment, receipt, discrepancies, and corrections — fully offline.',
                          ),
                        ],
                      ),
                    ),
                    if (canConfigure)
                      OutlinedButton.icon(
                        onPressed: () => _openPolicy(context, ref),
                        icon: const Icon(Icons.policy_outlined),
                        label: const Text('Approval policy'),
                      ),
                    FilledButton.icon(
                      onPressed: canCreate ? () => _create(context) : null,
                      icon: const Icon(Icons.add),
                      label: const Text('New transfer'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                transfers.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text('Transfers could not be loaded: $error'),
                    ),
                  ),
                  data: (items) => _TransferList(
                    items: items,
                    onOpen: (transfer) => _open(context, transfer),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _create(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateTransferDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer draft saved offline.')),
      );
    }
  }

  Future<void> _open(BuildContext context, StockTransfer transfer) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TransferDetailsDialog(transfer: transfer),
    );
  }

  Future<void> _openPolicy(BuildContext context, WidgetRef ref) async {
    final policy = await ref.read(transferPolicyProvider.future);
    if (!context.mounted || policy == null) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TransferPolicyDialog(policy: policy),
    );
  }
}

class _TransferList extends StatelessWidget {
  const _TransferList({required this.items, required this.onOpen});

  final List<StockTransfer> items;
  final ValueChanged<StockTransfer> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: Text('No transfers for this branch yet.')),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Transfer')),
            DataColumn(label: Text('Route')),
            DataColumn(label: Text('Status')),
            DataColumn(numeric: true, label: Text('Items')),
            DataColumn(numeric: true, label: Text('Quantity')),
            DataColumn(numeric: true, label: Text('Discrepancy')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final transfer in items)
              DataRow(
                cells: [
                  DataCell(Text(transfer.transferNumber)),
                  DataCell(
                    Text(
                      '${transfer.sourceBranchName} → ${transfer.destinationBranchName}',
                    ),
                  ),
                  DataCell(Chip(label: Text(transfer.status.label))),
                  DataCell(Text('${transfer.lines.length}')),
                  DataCell(
                    Text(
                      Formatters.quantityMilli(
                        transfer.totalRequestedQuantityMilli,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      Formatters.quantityMilli(
                        transfer.totalDiscrepancyQuantityMilli,
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      tooltip: 'Open transfer',
                      onPressed: () => onOpen(transfer),
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
