import 'package:flutter/material.dart';

import '../../../features/auth/domain/entities/auth_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

typedef BranchSelectionCallback =
    void Function(String organizationId, String branchId);

class SidebarBranchBadge extends StatelessWidget {
  const SidebarBranchBadge({
    super.key,
    required this.session,
    required this.onSelected,
    this.compact = false,
    this.iconOnly = false,
  });

  final AuthSession session;
  final BranchSelectionCallback onSelected;
  final bool compact;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopupMenuButton<_BranchSelection>(
      tooltip: 'Switch branch',
      onSelected: (selection) {
        onSelected(selection.organizationId, selection.branchId);
      },
      itemBuilder: (context) => [
        for (final organization in session.user.organizations)
          if (organization.canSignIn)
            for (final branch in organization.branches)
              PopupMenuItem(
                value: _BranchSelection(
                  organizationId: organization.organization.id,
                  branchId: branch.branch.id,
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    branch.branch.id == session.activeBranchId
                        ? Icons.check_circle
                        : Icons.storefront_outlined,
                  ),
                  title: Text(branch.branch.name),
                  subtitle: Text(organization.organization.name),
                ),
              ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.slate200,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact || iconOnly ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: compact || iconOnly
                ? MainAxisSize.min
                : MainAxisSize.max,
            mainAxisAlignment: iconOnly
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                Icons.storefront_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              if (!compact && !iconOnly) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.activeBranch.branch.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        session.activeOrganization.organization.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
              if (!iconOnly) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.unfold_more, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchSelection {
  const _BranchSelection({
    required this.organizationId,
    required this.branchId,
  });

  final String organizationId;
  final String branchId;
}
