import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../shared/models/sync_state.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_constants.dart';
import '../config/app_config.dart';
import '../database/database_provider.dart';
import '../routing/app_navigation_item.dart';
import '../routing/app_route.dart';
import '../sync/sync_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_confirmation_dialog.dart';
import 'desktop_sidebar.dart';
import 'mobile_bottom_navigation.dart';
import 'sidebar/sidebar_branch_badge.dart';

class AppNavigationShell extends ConsumerWidget {
  const AppNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final navigationItems = navigationItemsForSession(session);
    final selectedRoute =
        appNavigationItems[navigationShell.currentIndex].route;
    final syncState = ref.watch(syncStateProvider).asData?.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= AppBreakpoints.desktopNavigation;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                DesktopSidebar(
                  items: navigationItems,
                  selectedRoute: selectedRoute,
                  session: session,
                  onDestinationSelected: _goToItem,
                  onSettingsSelected: () => _goToRoute(AppRoute.settings),
                  onBranchSelected: (organizationId, branchId) =>
                      _selectBranch(ref, organizationId, branchId),
                  onLogout: () => _confirmLogout(context, ref),
                ),
                Expanded(
                  child: Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: _ShellTopBar(
                          title: selectedRoute.label,
                          session: session,
                          onBranchSelected: (organizationId, branchId) =>
                              _selectBranch(ref, organizationId, branchId),
                          onRefreshAccess: () => _refreshAccess(ref),
                          syncState: syncState,
                          onSync: () => _sync(ref),
                        ),
                      ),
                      Expanded(child: navigationShell),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(selectedRoute.label),
            actions: [
              IconButton(
                tooltip: syncState?.message ?? 'Synchronize now',
                onPressed: syncState?.status == SyncStatus.syncing
                    ? null
                    : () => _sync(ref),
                icon: syncState?.status == SyncStatus.syncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_syncIcon(syncState)),
              ),
              IconButton(
                tooltip: 'Refresh access',
                onPressed: () => _refreshAccess(ref),
                icon: const Icon(Icons.refresh),
              ),
              SidebarBranchBadge(
                session: session,
                compact: true,
                onSelected: (organizationId, branchId) =>
                    _selectBranch(ref, organizationId, branchId),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: navigationShell,
          bottomNavigationBar: MobileBottomNavigation(
            items: navigationItems,
            selectedRoute: selectedRoute,
            onDestinationSelected: _goToItem,
          ),
        );
      },
    );
  }

  void _goToItem(AppNavigationItem item) {
    _goToRoute(item.route);
  }

  void _goToRoute(AppRoute route) {
    final index = appNavigationItems.indexWhere(
      (navigationItem) => navigationItem.route == route,
    );

    if (index < 0) {
      return;
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _logout(WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final session = ref.read(authControllerProvider).asData?.value;
    var pending = 0;
    if (session != null && !ref.read(appConfigProvider).enableDemoAuth) {
      try {
        pending = await ref
            .read(outboxDaoProvider)
            .pendingCountFor(
              organizationId: session.activeOrganizationId,
              branchId: session.activeBranchId,
              actorUserId: session.activeOrganization.appUserId,
            );
      } catch (_) {
        // Sign-out remains available if local diagnostics cannot be read.
      }
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: 'Log out?',
        message: pending > 0
            ? '$pending local change(s) have not synchronized. They remain '
                  'in this device database and only this account can '
                  'upload them after signing in again.'
            : 'Are you sure you want to log out of your account?',
        confirmLabel: 'Logout',
        destructive: true,
        icon: Icons.logout_rounded,
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await _logout(ref);
  }

  Future<void> _selectBranch(
    WidgetRef ref,
    String organizationId,
    String branchId,
  ) {
    return ref
        .read(authControllerProvider.notifier)
        .selectActiveBranch(organizationId: organizationId, branchId: branchId);
  }

  Future<void> _refreshAccess(WidgetRef ref) {
    return ref.read(authControllerProvider.notifier).refreshAccess();
  }

  Future<void> _sync(WidgetRef ref) {
    return ref.read(syncStateProvider.notifier).synchronize();
  }

  IconData _syncIcon(SyncState? state) {
    return switch (state?.status) {
      SyncStatus.offline => Icons.cloud_off_outlined,
      SyncStatus.failed => Icons.sync_problem_outlined,
      _ =>
        state != null && (state.failedChanges > 0 || state.conflicts > 0)
            ? Icons.sync_problem_outlined
            : Icons.cloud_sync_outlined,
    };
  }
}

class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.title,
    required this.session,
    required this.onBranchSelected,
    required this.onRefreshAccess,
    required this.syncState,
    required this.onSync,
  });

  final String title;
  final AuthSession session;
  final BranchSelectionCallback onBranchSelected;
  final VoidCallback onRefreshAccess;
  final SyncState? syncState;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppConstants.appName, style: theme.textTheme.labelMedium),
              Text(title, style: theme.textTheme.titleLarge),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: syncState?.message ?? 'Synchronize now',
            onPressed: syncState?.status == SyncStatus.syncing ? null : onSync,
            icon: syncState?.status == SyncStatus.syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    syncState?.status == SyncStatus.offline
                        ? Icons.cloud_off_outlined
                        : (syncState?.failedChanges ?? 0) > 0 ||
                              (syncState?.conflicts ?? 0) > 0
                        ? Icons.sync_problem_outlined
                        : Icons.cloud_sync_outlined,
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Refresh access',
            onPressed: onRefreshAccess,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: AppSpacing.sm),
          SidebarBranchBadge(
            session: session,
            compact: true,
            onSelected: onBranchSelected,
          ),
        ],
      ),
    );
  }
}
