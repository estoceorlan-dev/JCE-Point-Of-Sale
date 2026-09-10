import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import '../../shared/models/sync_state.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'branch_selector.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    super.key,
    required this.title,
    required this.session,
    required this.sidebarToggle,
    required this.isDesktop,
    required this.onBranchSelected,
    required this.onRefreshAccess,
    required this.syncState,
    required this.onSync,
  });

  final String title;
  final AuthSession session;
  final Widget? sidebarToggle;
  final bool isDesktop;
  final BranchSelectionCallback onBranchSelected;
  final VoidCallback onRefreshAccess;
  final SyncState? syncState;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: isDesktop ? 72 : 64,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? AppSpacing.xxl : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.slate50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.slate200,
          ),
        ),
      ),
      child: Row(
        children: [
          if (sidebarToggle != null) ...[
            sidebarToggle!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  Text(
                    AppConstants.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: syncState?.message ?? 'Synchronize now',
            onPressed: syncState?.status == SyncStatus.syncing ? null : onSync,
            icon: syncState?.status == SyncStatus.syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(switch (syncState?.status) {
                    SyncStatus.offline => Icons.cloud_off_outlined,
                    SyncStatus.failed => Icons.sync_problem_outlined,
                    _ =>
                      (syncState?.failedChanges ?? 0) > 0 ||
                              (syncState?.conflicts ?? 0) > 0
                          ? Icons.sync_problem_outlined
                          : Icons.cloud_sync_outlined,
                  }),
          ),
          if (isDesktop) const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Refresh access',
            onPressed: onRefreshAccess,
            icon: const Icon(Icons.refresh),
          ),
          if (isDesktop) const SizedBox(width: AppSpacing.sm),
          BranchSelector(
            key: const ValueKey('app-bar-branch-selector'),
            session: session,
            maxWidth: isDesktop ? 232 : 136,
            onSelected: onBranchSelected,
          ),
        ],
      ),
    );
  }
}
