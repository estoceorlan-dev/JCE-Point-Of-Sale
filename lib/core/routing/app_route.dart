import '../../shared/models/permission.dart';

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
  users,
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
    AppRoute.users => 'users',
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
    AppRoute.users => '/users',
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
    AppRoute.users => 'Users',
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
    AppRoute.users => AppPermission.manageUsers,
    AppRoute.settings => AppPermission.manageSettings,
  };
}
