import 'package:flutter/material.dart';

import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class SidebarAction extends StatelessWidget {
  const SidebarAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.destructive = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool destructive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actionColor = destructive ? colorScheme.error : colorScheme.onSurface;
    final foregroundColor = selected ? colorScheme.primary : actionColor;

    final action = Semantics(
      button: true,
      selected: selected,
      label: compact ? label : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: compact
                ? Center(child: Icon(icon, color: foregroundColor, size: 24))
                : Row(
                    children: [
                      Icon(icon, color: foregroundColor, size: 24),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foregroundColor,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    return compact
        ? Tooltip(message: label, excludeFromSemantics: true, child: action)
        : action;
  }
}
