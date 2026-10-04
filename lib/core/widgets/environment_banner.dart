import 'package:flutter/material.dart';

import '../config/app_environment.dart';

class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({
    super.key,
    required this.environment,
    required this.child,
  });

  final AppEnvironment environment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (environment.isProduction) return child;

    return Banner(
      message: environment == AppEnvironment.staging
          ? 'STAGING'
          : 'DEVELOPMENT',
      location: BannerLocation.topEnd,
      color: environment == AppEnvironment.staging
          ? Colors.orange.shade800
          : Colors.red.shade700,
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
      child: child,
    );
  }
}
