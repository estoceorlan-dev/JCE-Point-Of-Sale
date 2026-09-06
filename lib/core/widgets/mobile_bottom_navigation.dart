import 'package:flutter/material.dart';

import '../routing/app_navigation_item.dart';
import '../routing/app_route.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

class MobileBottomNavigation extends StatelessWidget {
  const MobileBottomNavigation({
    super.key,
    required this.items,
    required this.selectedRoute,
    required this.onDestinationSelected,
  });

  final List<AppNavigationItem> items;
  final AppRoute selectedRoute;
  final ValueChanged<AppNavigationItem> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.slate200,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.mobileNavHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                for (var index = 0; index < items.take(3).length; index++)
                  _MobileDestination(
                    item: items[index],
                    selected: selectedRoute == items[index].route,
                    onTap: () => onDestinationSelected(items[index]),
                  ),
                SizedBox(
                  width: 78,
                  child: TextButton(
                    onPressed: () => _showDestinations(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu),
                        SizedBox(height: 8),
                        Text('More'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDestinations(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.75,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final section in AppNavigationSection.values)
                  if (items.any((item) => item.section == section)) ...[
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(
                        section.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final item in items.where(
                      (item) => item.section == section,
                    ))
                      ListTile(
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        selected: item.route == selectedRoute,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onDestinationSelected(item);
                        },
                      ),
                  ],
              ],
            ),
          ),
        ),
      );
}

class _MobileDestination extends StatelessWidget {
  const _MobileDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            width: 78,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 20,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
