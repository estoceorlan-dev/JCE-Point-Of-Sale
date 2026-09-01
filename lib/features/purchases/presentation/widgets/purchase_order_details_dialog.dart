import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/purchase_order.dart';
import '../controllers/purchase_mutation_controller.dart';
import '../providers/purchases_providers.dart';
import 'receive_purchase_order_dialog.dart';

class PurchaseOrderDetailsDialog extends ConsumerStatefulWidget {
  const PurchaseOrderDetailsDialog({required this.order, super.key});

  final PurchaseOrder order;

  @override
  ConsumerState<PurchaseOrderDetailsDialog> createState() =>
      _PurchaseOrderDetailsDialogState();
}

class _PurchaseOrderDetailsDialogState
    extends ConsumerState<PurchaseOrderDetailsDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final session = ref.watch(activePurchaseSessionProvider);
    final saving = ref.watch(purchaseMutationControllerProvider).isLoading;
    final canCreate = session?.can(AppPermission.createPurchases) ?? false;
    final canApprove = session?.can(AppPermission.approvePurchases) ?? false;
    final canReceive = session?.can(AppPermission.receivePurchases) ?? false;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(order.orderNumber)),
          Chip(label: Text(order.status.label)),
        ],
      ),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.sm,
                children: [
                  _Fact(label: 'Supplier', value: order.supplierName),
                  _Fact(
                    label: 'Ordered',
                    value: Formatters.quantityMilli(
                      order.totalOrderedQuantityMilli,
                    ),
                  ),
                  _Fact(
                    label: 'Received',
                    value: Formatters.quantityMilli(
                      order.totalReceivedQuantityMilli,
                    ),
                  ),
                  _Fact(
                    label: 'Remaining',
                    value: Formatters.quantityMilli(
                      order.totalRemainingQuantityMilli,
                    ),
                  ),
                  _Fact(
                    label: 'Order value',
                    value: Formatters.currencyMinor(order.totalMinor),
                  ),
                ],
              ),
              if (order.notes != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(order.notes!),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Order items',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(numeric: true, label: Text('Ordered')),
                    DataColumn(numeric: true, label: Text('Received')),
                    DataColumn(numeric: true, label: Text('Cancelled')),
                    DataColumn(numeric: true, label: Text('Remaining')),
                    DataColumn(numeric: true, label: Text('Unit cost')),
                  ],
                  rows: [
                    for (final line in order.lines)
                      DataRow(
                        cells: [
                          DataCell(Text('${line.sku} — ${line.productName}')),
                          DataCell(
                            Text(
                              Formatters.quantityMilli(
                                line.orderedQuantityMilli,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              Formatters.quantityMilli(
                                line.receivedQuantityMilli,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              Formatters.quantityMilli(
                                line.cancelledQuantityMilli,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              Formatters.quantityMilli(
                                line.remainingQuantityMilli,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(Formatters.currencyMinor(line.unitCostMinor)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Goods receipts and cost history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (order.receipts.isEmpty)
                const Text('No physical receipts posted yet.')
              else
                for (final receipt in order.receipts)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ExpansionTile(
                      title: Text(receipt.receiptNumber),
                      subtitle: Text(
                        '${receipt.stockLocationName} • ${receipt.receivedAt.toLocal()}',
                      ),
                      children: [
                        for (final line in receipt.lines)
                          ListTile(
                            title: Text(line.productName),
                            subtitle: Text(
                              '${Formatters.quantityMilli(line.receivedQuantityMilli)} received • '
                              'landed ${Formatters.currencyMinor(line.landedUnitCostMinor)} / unit',
                            ),
                            trailing: Text(
                              'Avg ${Formatters.currencyMinor(line.weightedAverageCostMinorAfter)}',
                            ),
                          ),
                      ],
                    ),
                  ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (canCreate &&
            order.status != PurchaseOrderStatus.received &&
            order.status != PurchaseOrderStatus.cancelled)
          TextButton(
            onPressed: saving ? null : _cancel,
            child: const Text('Cancel order'),
          ),
        if (canCreate && order.status == PurchaseOrderStatus.draft)
          FilledButton.tonal(
            onPressed: saving ? null : _submit,
            child: const Text('Submit for approval'),
          ),
        if (canApprove && order.status == PurchaseOrderStatus.submitted)
          FilledButton.tonal(
            onPressed: saving ? null : _approve,
            child: const Text('Approve'),
          ),
        if (canReceive &&
            (order.status == PurchaseOrderStatus.approved ||
                order.status == PurchaseOrderStatus.partiallyReceived))
          FilledButton.icon(
            onPressed: saving ? null : _receive,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Receive delivery'),
          ),
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final result = await ref
        .read(purchaseMutationControllerProvider.notifier)
        .submit(widget.order);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }

  Future<void> _approve() async {
    final result = await ref
        .read(purchaseMutationControllerProvider.notifier)
        .approve(widget.order);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }

  Future<void> _receive() async {
    final received = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceivePurchaseOrderDialog(order: widget.order),
    );
    if (received == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _CancellationReasonDialog(),
    );
    if (reason == null || !mounted) return;
    final result = await ref
        .read(purchaseMutationControllerProvider.notifier)
        .cancel(widget.order, reason);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _CancellationReasonDialog extends StatefulWidget {
  const _CancellationReasonDialog();

  @override
  State<_CancellationReasonDialog> createState() =>
      _CancellationReasonDialogState();
}

class _CancellationReasonDialogState extends State<_CancellationReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel purchase order'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Reason'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(context, value);
          },
          child: const Text('Cancel order'),
        ),
      ],
    );
  }
}
