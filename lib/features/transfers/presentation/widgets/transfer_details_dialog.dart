import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/stock_transfer.dart';
import '../controllers/transfer_mutation_controller.dart';
import '../providers/transfers_providers.dart';
import 'receive_transfer_dialog.dart';

class TransferDetailsDialog extends ConsumerStatefulWidget {
  const TransferDetailsDialog({super.key, required this.transfer});

  final StockTransfer transfer;

  @override
  ConsumerState<TransferDetailsDialog> createState() =>
      _TransferDetailsDialogState();
}

class _TransferDetailsDialogState extends ConsumerState<TransferDetailsDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final transfer = widget.transfer;
    final session = ref.watch(activeTransferSessionProvider);
    final saving = ref.watch(transferMutationControllerProvider).isLoading;
    final isSource = session?.activeBranchId == transfer.sourceBranchId;
    final isDestination =
        session?.activeBranchId == transfer.destinationBranchId;
    final canManage = session?.can(AppPermission.manageInventory) ?? false;
    final canApprove = session?.can(AppPermission.approveTransfers) ?? false;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(transfer.transferNumber)),
          _StatusChip(status: transfer.status),
        ],
      ),
      content: SizedBox(
        width: 780,
        height: 570,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${transfer.sourceBranchName} → ${transfer.destinationBranchName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (transfer.notes != null) Text(transfer.notes!),
              const SizedBox(height: AppSpacing.lg),
              Text('Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('From / to')),
                    DataColumn(numeric: true, label: Text('Requested')),
                    DataColumn(numeric: true, label: Text('Shipped')),
                    DataColumn(numeric: true, label: Text('Received')),
                    DataColumn(numeric: true, label: Text('Damaged')),
                    DataColumn(numeric: true, label: Text('Discrepancy')),
                  ],
                  rows: [
                    for (final line in transfer.lines)
                      DataRow(
                        cells: [
                          DataCell(Text('${line.sku} — ${line.productName}')),
                          DataCell(
                            Text(
                              '${line.sourceLocationName} → ${line.destinationLocationName}',
                            ),
                          ),
                          DataCell(
                            Text(
                              Formatters.quantityMilli(
                                line.requestedQuantityMilli,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              Formatters.quantityMilli(
                                line.shippedQuantityMilli,
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
                                line.damagedQuantityMilli,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              Formatters.quantityMilli(
                                line.discrepancyQuantityMilli,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final event in transfer.events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(event.eventType.replaceAll('_', ' ')),
                  subtitle: Text(
                    '${event.fromStatus?.label ?? 'New'} → ${event.toStatus.label}'
                    '${event.reason == null ? '' : ' • ${event.reason}'}',
                  ),
                  trailing: Text(_formatDate(event.occurredAt)),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (isSource &&
            canManage &&
            transfer.status == StockTransferStatus.draft)
          FilledButton.tonal(
            onPressed: saving ? null : () => _act('submit'),
            child: const Text('Submit'),
          ),
        if (isSource &&
            canApprove &&
            transfer.status == StockTransferStatus.submitted) ...[
          TextButton(
            onPressed: saving ? null : () => _actWithReason('reject'),
            child: const Text('Reject'),
          ),
          FilledButton.tonal(
            onPressed: saving ? null : () => _act('approve'),
            child: const Text('Approve'),
          ),
        ],
        if (isSource &&
            canManage &&
            transfer.status == StockTransferStatus.approved)
          FilledButton.tonal(
            onPressed: saving ? null : () => _act('ship'),
            child: const Text('Ship'),
          ),
        if (isDestination &&
            canManage &&
            transfer.status == StockTransferStatus.shipped)
          FilledButton.tonal(
            onPressed: saving ? null : _receive,
            child: const Text('Receive'),
          ),
        if (isDestination &&
            canApprove &&
            transfer.status == StockTransferStatus.received)
          OutlinedButton(
            onPressed: saving ? null : () => _receive(correction: true),
            child: const Text('Correct receipt'),
          ),
        if (isSource &&
            canManage &&
            const {
              StockTransferStatus.draft,
              StockTransferStatus.submitted,
              StockTransferStatus.approved,
            }.contains(transfer.status))
          TextButton(
            onPressed: saving ? null : () => _actWithReason('cancel'),
            child: const Text('Cancel transfer'),
          ),
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _act(String action) async {
    setState(() => _error = null);
    final controller = ref.read(transferMutationControllerProvider.notifier);
    final result = switch (action) {
      'submit' => await controller.submit(widget.transfer),
      'approve' => await controller.approve(widget.transfer),
      'ship' => await controller.ship(widget.transfer),
      _ => throw ArgumentError.value(action),
    };
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }

  Future<void> _actWithReason(String action) async {
    final reason = await _askReason(
      action == 'reject' ? 'Reject transfer' : 'Cancel transfer',
    );
    if (reason == null || !mounted) return;
    setState(() => _error = null);
    final controller = ref.read(transferMutationControllerProvider.notifier);
    final result = action == 'reject'
        ? await controller.reject(widget.transfer, reason)
        : await controller.cancel(widget.transfer, reason);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }

  Future<void> _receive({bool correction = false}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiveTransferDialog(
        transfer: widget.transfer,
        correction: correction,
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  Future<String?> _askReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Required reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) Navigator.pop(context, reason);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final StockTransferStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StockTransferStatus.received => AppColors.success,
      StockTransferStatus.rejected ||
      StockTransferStatus.cancelled => AppColors.danger,
      StockTransferStatus.shipped => AppColors.warning,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Chip(
      label: Text(status.label),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
