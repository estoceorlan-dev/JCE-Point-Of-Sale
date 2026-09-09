import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

class SidebarLogo extends StatelessWidget {
  const SidebarLogo({
    super.key,
    required this.asset,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.compact = false,
  });

  final String asset;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.md : AppSpacing.lg,
        AppSpacing.xl,
        compact ? AppSpacing.md : AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
          ),
          if (!compact) ...[
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ],
      ),
    );
  }
}
