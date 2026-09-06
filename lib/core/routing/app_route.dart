import '../../shared/models/permission.dart';
import '../../features/auth/domain/entities/auth_session.dart';

enum AppRoute {
  auth,
  dashboard,
  pos,
  products,
  inventory,
  transfers,
  purchases,
  customers,
  reports,
  logs,
  branches,
  users,
  registers,
  settings,
}

extension AppRouteInfo on AppRoute {
  String get routeName => switch (this) {
    AppRoute.auth => 'auth',
    AppRoute.dashboard => 'dashboard',
    AppRoute.pos => 'pos',
    AppRoute.products => 'products',
    AppRoute.inventory => 'inventory',
    AppRoute.transfers => 'transfers',
    AppRoute.purchases => 'purchases',
    AppRoute.customers => 'customers',
    AppRoute.reports => 'reports',
    AppRoute.logs => 'logs',
    AppRoute.branches => 'branches',
    AppRoute.users => 'users',
    AppRoute.registers => 'registers',
    AppRoute.settings => 'settings',
  };

  String get path => switch (this) {
    AppRoute.auth => '/auth',
    AppRoute.dashboard => '/',
    AppRoute.pos => '/pos',
    AppRoute.products => '/products',
    AppRoute.inventory => '/inventory',
    AppRoute.transfers => '/transfers',
    AppRoute.purchases => '/purchases',
    AppRoute.customers => '/customers',
    AppRoute.reports => '/reports',
    AppRoute.logs => '/logs',
    AppRoute.branches => '/branches',
    AppRoute.users => '/staff',
    AppRoute.registers => '/registers',
    AppRoute.settings => '/settings',
  };

  String get label => switch (this) {
    AppRoute.auth => 'Auth',
    AppRoute.dashboard => 'Dashboard',
    AppRoute.pos => 'POS',
    AppRoute.products => 'Products',
    AppRoute.inventory => 'Inventory',
    AppRoute.transfers => 'Transfers',
    AppRoute.purchases => 'Purchases',
    AppRoute.customers => 'Customers',
    AppRoute.reports => 'Reports',
    AppRoute.logs => 'Logs',
    AppRoute.branches => 'Branches',
    AppRoute.users => 'Staff & Access',
    AppRoute.registers => 'Registers & Hardware',
    AppRoute.settings => 'Settings',
  };

  AppPermission? get requiredPermission => switch (this) {
    AppRoute.auth => null,
    AppRoute.dashboard => AppPermission.viewDashboard,
    AppRoute.pos => AppPermission.processSales,
    AppRoute.products => AppPermission.manageProducts,
    AppRoute.inventory => AppPermission.manageInventory,
    AppRoute.transfers => AppPermission.manageInventory,
    AppRoute.purchases => AppPermission.createPurchases,
    AppRoute.customers => AppPermission.viewCustomers,
    AppRoute.reports => AppPermission.viewReports,
    AppRoute.logs => AppPermission.viewAuditLogs,
    AppRoute.branches => AppPermission.manageBranches,
    AppRoute.users => AppPermission.manageUsers,
    AppRoute.registers => AppPermission.manageRegisters,
    AppRoute.settings => AppPermission.manageSettings,
  };

  bool canAccess(AuthSession session) => switch (this) {
    AppRoute.branches => session.canOrganizationWide(
      AppPermission.manageBranches,
    ),
    AppRoute.users =>
      session.canOrganizationWide(AppPermission.manageUsers) ||
          session.canOrganizationWide(AppPermission.manageRoles),
    _ => requiredPermission == null || session.can(requiredPermission!),
  };
}
