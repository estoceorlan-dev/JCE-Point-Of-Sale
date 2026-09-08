import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    required this.description,
    required this.action,
    super.key,
  });

  final String title;
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
      if (constraints.maxWidth <
          640 * MediaQuery.textScalerOf(context).scale(1)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            const SizedBox(height: AppSpacing.md),
            action,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          const SizedBox(width: AppSpacing.md),
          action,
        ],
      );
    },
  );
}
