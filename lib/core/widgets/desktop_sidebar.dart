import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import '../constants/app_constants.dart';
import '../routing/app_navigation_item.dart';
import '../routing/app_route.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'sidebar/sidebar_action.dart';
import 'sidebar/sidebar_branch_badge.dart';
import 'sidebar/sidebar_logo.dart';
import 'sidebar/sidebar_user_panel.dart';

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.items,
    required this.selectedRoute,
    required this.session,
    required this.onDestinationSelected,
    required this.onSettingsSelected,
    required this.onBranchSelected,
    required this.onLogout,
  });

  static const _logoAsset = 'assets/images/jce_logo.jpg';

  final List<AppNavigationItem> items;
  final AppRoute selectedRoute;
  final AuthSession session;
  final ValueChanged<AppNavigationItem> onDestinationSelected;
  final VoidCallback onSettingsSelected;
  final BranchSelectionCallback onBranchSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mainItems = items
        .where((item) => item.route != AppRoute.settings)
        .toList();
    final canOpenSettings = items.any(
      (item) => item.route == AppRoute.settings,
    );

    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.slate200,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SidebarLogo(
              asset: _logoAsset,
              title: AppConstants.appName,
              subtitle: 'Dry Goods Trading',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  for (final section in AppNavigationSection.values)
                    if (mainItems.any((item) => item.section == section)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.xs,
                        ),
                        child: Text(
                          section.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      for (final item in mainItems.where(
                        (item) => item.section == section,
                      )) ...[
                        SidebarAction(
                          label: item.label,
                          icon: item.route == selectedRoute
                              ? item.selectedIcon
                              : item.icon,
                          selected: item.route == selectedRoute,
                          onTap: () => onDestinationSelected(item),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SidebarUserPanel(session: session),
                  const SizedBox(height: AppSpacing.md),
                  if (canOpenSettings) ...[
                    SidebarAction(
                      label: 'Settings',
                      icon: selectedRoute == AppRoute.settings
                          ? Icons.settings
                          : Icons.settings_outlined,
                      selected: selectedRoute == AppRoute.settings,
                      onTap: onSettingsSelected,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  SidebarAction(
                    label: 'Logout',
                    icon: Icons.logout,
                    onTap: onLogout,
                    destructive: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SidebarBranchBadge(
                    session: session,
                    onSelected: onBranchSelected,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
