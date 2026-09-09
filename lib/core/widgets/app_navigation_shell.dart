import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../config/app_config.dart';
import '../database/database_provider.dart';
import '../routing/app_navigation_item.dart';
import '../routing/app_route.dart';
import '../sync/sync_controller.dart';
import 'app_confirmation_dialog.dart';
import 'app_sidebar_layout.dart';
import 'desktop_sidebar.dart';
import 'mobile_bottom_navigation.dart';
import 'shell_top_bar.dart';

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

    return AppSidebarLayout(
      sidebarBuilder: (context, toggle, isDesktop, collapsed) => DesktopSidebar(
        items: navigationItems,
        selectedRoute: selectedRoute,
        session: session,
        onToggle: toggle,
        collapseToRail: isDesktop,
        collapsed: collapsed,
        onDestinationSelected: (item) {
          if (!isDesktop) toggle();
          _goToItem(item);
        },
        onSettingsSelected: () {
          if (!isDesktop) toggle();
          _goToRoute(AppRoute.settings);
        },
        onBranchSelected: (organizationId, branchId) =>
            _selectBranch(ref, organizationId, branchId),
        onLogout: () {
          if (!isDesktop) toggle();
          _confirmLogout(context, ref);
        },
      ),
      headerBuilder: (context, toggle, isDesktop) => ShellTopBar(
        title: selectedRoute.label,
        session: session,
        sidebarToggle: toggle,
        isDesktop: isDesktop,
        onBranchSelected: (organizationId, branchId) =>
            _selectBranch(ref, organizationId, branchId),
        onRefreshAccess: () => _refreshAccess(ref),
        syncState: syncState,
        onSync: () => _sync(ref),
      ),
      body: navigationShell,
      bottomNavigationBar: MobileBottomNavigation(
        items: navigationItems,
        selectedRoute: selectedRoute,
        onDestinationSelected: _goToItem,
      ),
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
}
