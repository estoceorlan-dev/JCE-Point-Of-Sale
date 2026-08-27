import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/metric_tile.dart';
import '../../../../shared/providers/app_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncState = ref.watch(syncStateProvider).asData?.value;
    final pending = syncState == null
        ? '…'
        : (syncState.pendingChanges +
                  syncState.retryingChanges +
                  syncState.failedChanges +
                  syncState.conflicts)
              .toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < AppBreakpoints.compact
            ? AppSpacing.lg
            : AppSpacing.xxl;
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
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
                  Text(AppConstants.appName, style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Dashboard', style: theme.textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sales, inventory, branch activity, and sync health.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      const MetricTile(
                        title: 'Today sales',
                        value: 'PHP 0.00',
                        detail: 'Completed local sales',
                        icon: Icons.payments_outlined,
                      ),
                      const MetricTile(
                        title: 'Open carts',
                        value: '0',
                        detail: 'Current register activity',
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const MetricTile(
                        title: 'Low stock',
                        value: '0',
                        detail: 'Branch inventory thresholds',
                        icon: Icons.warning_amber_outlined,
                      ),
                      MetricTile(
                        title: 'Pending sync',
                        value: pending,
                        detail:
                            syncState?.message ??
                            'Local changes waiting for the backend',
                        icon: Icons.cloud_sync_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sync diagnostics',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Pending ${syncState?.pendingChanges ?? 0}  •  '
                            'Retrying ${syncState?.retryingChanges ?? 0}  •  '
                            'Failed ${syncState?.failedChanges ?? 0}  •  '
                            'Conflicts ${syncState?.conflicts ?? 0}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
