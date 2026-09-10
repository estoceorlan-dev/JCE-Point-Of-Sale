import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

typedef BranchSelectionCallback =
    void Function(String organizationId, String branchId);

class BranchSelector extends StatelessWidget {
  const BranchSelector({
    super.key,
    required this.session,
    required this.onSelected,
    this.maxWidth = 232,
  });

  final AuthSession session;
  final BranchSelectionCallback onSelected;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeBranch = session.activeBranch.branch;

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
                    branch.branch.id == session.activeBranchId &&
                            organization.organization.id ==
                                session.activeOrganizationId
                        ? Icons.check_circle
                        : Icons.storefront_outlined,
                  ),
                  title: Text(branch.branch.name),
                  subtitle: Text(organization.organization.name),
                ),
              ),
      ],
      child: Semantics(
        button: true,
        label: 'Current branch: ${activeBranch.name}',
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.slate200,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      activeBranch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.unfold_more, size: 18),
                ],
              ),
            ),
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
