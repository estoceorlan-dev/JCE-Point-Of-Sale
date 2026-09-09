import 'package:flutter/material.dart';

import '../../../features/auth/domain/entities/auth_session.dart';
import '../../theme/app_spacing.dart';

class SidebarUserPanel extends StatelessWidget {
  const SidebarUserPanel({
    super.key,
    required this.session,
    this.compact = false,
  });

  final AuthSession session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = user.displayName.trim();
    final initialSource = displayName.isEmpty ? user.email : displayName;
    final roleLabel = session.roles.isEmpty
        ? 'No role'
        : session.roles.map((role) => role.name).join(', ');

    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      foregroundColor: colorScheme.primary,
      child: Text(
        initialSource.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    if (compact) {
      return Tooltip(
        message: '$initialSource\n$roleLabel',
        child: Center(child: avatar),
      );
    }
    return Row(
      children: [
        avatar,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName.isEmpty ? user.email : displayName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              Text(
                roleLabel,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
