import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/branches/presentation/pages/branches_page.dart';
import '../../features/branches/presentation/pages/branch_details_page.dart';
import '../../features/shifts/presentation/pages/shift_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/customers/presentation/pages/customers_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/logs/presentation/pages/logs_page.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/purchases/presentation/pages/purchases_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/transfers/presentation/pages/transfers_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../widgets/app_navigation_shell.dart';
import 'app_navigation_item.dart';
import 'app_route.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, _) => refreshNotifier.refresh());

  final initialSession = ref.read(authControllerProvider).asData?.value;
  final router = GoRouter(
    initialLocation: initialSession == null
        ? AppRoute.auth.path
        : AppRoute.dashboard.path,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final currentUser = ref.read(authControllerProvider);
      final session = currentUser.asData?.value;
      final isAuthRoute = state.matchedLocation == AppRoute.auth.path;

      if (currentUser.isLoading) {
        return isAuthRoute ? null : AppRoute.auth.path;
      }

      if (session == null) {
        return isAuthRoute ? null : AppRoute.auth.path;
      }

      if (isAuthRoute) {
        return _firstAccessiblePath(session);
      }

      final route = _routeForLocation(state.matchedLocation);
      final hasAccess = route == null || route.canAccess(session);

      if (hasAccess) {
        return null;
      }
      return _firstAccessiblePath(session) ?? AppRoute.auth.path;
    },
    routes: [
      GoRoute(
        path: '/users',
        redirect: (context, state) => AppRoute.users.path,
      ),
      GoRoute(
        path: AppRoute.auth.path,
        name: AppRoute.auth.routeName,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const LoginPage(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          _branch(AppRoute.dashboard, const DashboardPage()),
          _branch(AppRoute.pos, const PosPage()),
          _branch(AppRoute.products, const ProductsPage()),
          _branch(AppRoute.inventory, const InventoryPage()),
          _branch(AppRoute.transfers, const TransfersPage()),
          _branch(AppRoute.purchases, const PurchasesPage()),
          _branch(AppRoute.customers, const CustomersPage()),
          _branch(AppRoute.reports, const ReportsPage()),
          _branch(AppRoute.logs, const LogsPage()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.branches.path,
                name: AppRoute.branches.routeName,
                builder: (_, _) => const BranchesPage(),
                routes: [
                  GoRoute(
                    path: ':branchId',
                    builder: (_, state) => BranchDetailsPage(
                      branchId: state.pathParameters['branchId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _branch(AppRoute.users, const UsersPage()),
          _branch(
            AppRoute.registers,
            const ShiftPage(administrationOnly: true),
          ),
          _branch(AppRoute.settings, const SettingsPage()),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

String? _firstAccessiblePath(AuthSession session) {
  for (final item in appNavigationItems) {
    if (item.route.canAccess(session)) {
      return item.route.path;
    }
  }
  return null;
}

AppRoute? _routeForLocation(String location) {
  for (final item in appNavigationItems) {
    if (item.route.path == location ||
        (item.route != AppRoute.dashboard &&
            location.startsWith('${item.route.path}/'))) {
      return item.route;
    }
  }

  if (location == AppRoute.auth.path) {
    return AppRoute.auth;
  }

  return null;
}

StatefulShellBranch _branch(AppRoute route, Widget child) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: route.path,
        name: route.routeName,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: route == AppRoute.users
              ? UsersPage(branchId: state.uri.queryParameters['branchId'])
              : child,
        ),
      ),
    ],
  );
}
