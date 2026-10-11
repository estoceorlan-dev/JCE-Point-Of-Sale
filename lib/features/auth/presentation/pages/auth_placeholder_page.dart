import 'package:flutter/material.dart';

import '../../../../core/widgets/feature_placeholder_page.dart';

class AuthPlaceholderPage extends StatelessWidget {
  const AuthPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Authentication',
      subtitle: 'Account access and enrolled offline cashier sign-in.',
      icon: Icons.lock_outline,
      highlights: [
        'API account sign-in and device-bound offline cashier PINs.',
        'Role and branch assignment resolved after sign-in.',
        'Auth state exposed through repository and Riverpod providers.',
      ],
    );
  }
}
