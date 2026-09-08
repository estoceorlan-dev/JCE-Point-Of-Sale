import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/sync_state.dart';
import '../../../hardware/domain/entities/register_hardware_profile.dart';

class TerminalStatusStrip extends StatelessWidget {
  const TerminalStatusStrip({
    required this.branchName,
    required this.registerName,
    required this.cashierName,
    required this.shiftOpen,
    required this.syncState,
    required this.scannerType,
    required this.printerType,
    super.key,
  });

  final String branchName;
  final String registerName;
  final String cashierName;
  final bool shiftOpen;
  final SyncState? syncState;
  final BarcodeScannerType? scannerType;
  final ReceiptPrinterType? printerType;

  @override
  Widget build(BuildContext context) {
    final sync = _syncPresentation(syncState);
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            _StatusItem(icon: Icons.storefront_outlined, label: branchName),
            _StatusItem(
              icon: Icons.point_of_sale_outlined,
              label: registerName,
            ),
            _StatusItem(icon: Icons.badge_outlined, label: cashierName),
            _StatusItem(
              icon: shiftOpen ? Icons.lock_open_outlined : Icons.lock_outline,
              label: shiftOpen ? 'Shift open' : 'Shift closed',
              color: shiftOpen ? AppColors.success : null,
            ),
            _StatusItem(
              key: const Key('terminal-sync-status'),
              icon: sync.icon,
              label: sync.label,
              color: sync.color,
            ),
            _StatusItem(
              icon: Icons.qr_code_scanner_outlined,
              label: scannerType?.label ?? 'Scanner unavailable',
            ),
            _StatusItem(
              icon: Icons.print_outlined,
              label: printerType?.label ?? 'Printer unavailable',
            ),
          ],
        ),
      ),
    );
  }
}

_SyncPresentation _syncPresentation(SyncState? state) {
  if (state == null) {
    return const _SyncPresentation(
      icon: Icons.cloud_off_outlined,
      label: 'Sync unavailable',
      color: AppColors.warning,
    );
  }
  final queued = state.pendingChanges + state.retryingChanges;
  final detail = [
    if (queued > 0) '$queued queued',
    if (state.failedChanges > 0) '${state.failedChanges} failed',
    if (state.conflicts > 0) '${state.conflicts} conflicts',
  ].join(' · ');
  final suffix = detail.isEmpty ? '' : ' · $detail';
  final clean = queued == 0 && state.failedChanges == 0 && state.conflicts == 0;
  return switch (state.status) {
    SyncStatus.idle => _SyncPresentation(
      icon: clean ? Icons.cloud_done_outlined : Icons.cloud_queue_outlined,
      label: clean ? 'Synced' : 'Saved locally$suffix',
      color: state.failedChanges > 0
          ? AppColors.danger
          : state.conflicts > 0
          ? AppColors.warning
          : null,
    ),
    SyncStatus.syncing => _SyncPresentation(
      icon: Icons.sync,
      label: 'Syncing$suffix',
      color: null,
    ),
    SyncStatus.offline => _SyncPresentation(
      icon: Icons.cloud_off_outlined,
      label: 'Offline$suffix',
      color: AppColors.warning,
    ),
    SyncStatus.failed => _SyncPresentation(
      icon: Icons.sync_problem_outlined,
      label: 'Sync needs attention$suffix',
      color: AppColors.danger,
    ),
  };
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.icon,
    required this.label,
    this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

class _SyncPresentation {
  const _SyncPresentation({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;
}
