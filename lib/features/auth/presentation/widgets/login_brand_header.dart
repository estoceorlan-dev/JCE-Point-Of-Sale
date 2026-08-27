import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key, required this.logoAsset});

  final String logoAsset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface.withValues(alpha: 0.95),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              logoAsset,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}
