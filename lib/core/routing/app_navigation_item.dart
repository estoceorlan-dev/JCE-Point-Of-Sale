import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import '../../shared/models/permission.dart';
import 'app_route.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.section,
  });

  final AppRoute route;
  final IconData icon;
  final IconData selectedIcon;
  final AppNavigationSection section;

  String get label => route.label;
  AppPermission get permission => route.requiredPermission!;
}

enum AppNavigationSection {
  operations('Operations'),
  catalog('Catalog & stock'),
  insights('Insights'),
  administration('Administration');

  const AppNavigationSection(this.label);
  final String label;
}

const appNavigationItems = <AppNavigationItem>[
  AppNavigationItem(
    route: AppRoute.dashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    section: AppNavigationSection.insights,
  ),
  AppNavigationItem(
    route: AppRoute.pos,
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
    section: AppNavigationSection.operations,
  ),
  AppNavigationItem(
    route: AppRoute.products,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    section: AppNavigationSection.catalog,
  ),
  AppNavigationItem(
    route: AppRoute.inventory,
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse,
    section: AppNavigationSection.catalog,
  ),
  AppNavigationItem(
    route: AppRoute.transfers,
    icon: Icons.sync_alt_outlined,
    selectedIcon: Icons.sync_alt,
    section: AppNavigationSection.catalog,
  ),
  AppNavigationItem(
    route: AppRoute.purchases,
    icon: Icons.shopping_cart_checkout_outlined,
    selectedIcon: Icons.shopping_cart_checkout,
    section: AppNavigationSection.catalog,
  ),
  AppNavigationItem(
    route: AppRoute.customers,
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    section: AppNavigationSection.operations,
  ),
  AppNavigationItem(
    route: AppRoute.reports,
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    section: AppNavigationSection.insights,
  ),
  AppNavigationItem(
    route: AppRoute.logs,
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
    section: AppNavigationSection.administration,
  ),
  AppNavigationItem(
    route: AppRoute.branches,
    icon: Icons.store_outlined,
    selectedIcon: Icons.store,
    section: AppNavigationSection.administration,
  ),
  AppNavigationItem(
    route: AppRoute.users,
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    section: AppNavigationSection.administration,
  ),
  AppNavigationItem(
    route: AppRoute.registers,
    icon: Icons.devices_outlined,
    selectedIcon: Icons.devices,
    section: AppNavigationSection.administration,
  ),
  AppNavigationItem(
    route: AppRoute.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    section: AppNavigationSection.administration,
  ),
];

List<AppNavigationItem> navigationItemsForSession(AuthSession session) {
  return appNavigationItems
      .where((item) => item.route.canAccess(session))
      .toList(growable: false);
}
