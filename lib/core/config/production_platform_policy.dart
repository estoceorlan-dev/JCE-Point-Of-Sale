import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';
import 'app_environment.dart';

enum AppClientPlatform { web, android, windows, ios, macos, linux, other }

final productionPlatformPolicyProvider = Provider<ProductionPlatformPolicy>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.useNodeBackend && kIsWeb) {
    return const ProductionPlatformPolicy(
      platform: AppClientPlatform.web,
      isSupported: true,
      allowsPointOfSale: false,
    );
  }
  return ProductionPlatformPolicy.forEnvironment(
    environment: ref.watch(appConfigProvider).environment,
    platform: currentAppClientPlatform(),
  );
});

AppClientPlatform currentAppClientPlatform() {
  if (kIsWeb) return AppClientPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AppClientPlatform.android,
    TargetPlatform.windows => AppClientPlatform.windows,
    TargetPlatform.iOS => AppClientPlatform.ios,
    TargetPlatform.macOS => AppClientPlatform.macos,
    TargetPlatform.linux => AppClientPlatform.linux,
    _ => AppClientPlatform.other,
  };
}

class ProductionPlatformPolicy {
  const ProductionPlatformPolicy({
    required this.platform,
    required this.isSupported,
    required this.allowsPointOfSale,
    this.blockReason,
  });

  factory ProductionPlatformPolicy.forEnvironment({
    required AppEnvironment environment,
    required AppClientPlatform platform,
  }) {
    if (!environment.isProduction) {
      return ProductionPlatformPolicy(
        platform: platform,
        isSupported: true,
        allowsPointOfSale: true,
      );
    }

    return switch (platform) {
      AppClientPlatform.android => const ProductionPlatformPolicy(
        platform: AppClientPlatform.android,
        isSupported: true,
        allowsPointOfSale: true,
      ),
      AppClientPlatform.web => const ProductionPlatformPolicy(
        platform: AppClientPlatform.web,
        isSupported: true,
        allowsPointOfSale: false,
      ),
      AppClientPlatform.windows => const ProductionPlatformPolicy(
        platform: AppClientPlatform.windows,
        isSupported: false,
        allowsPointOfSale: false,
        blockReason:
            'Production Windows is deferred by ADR-0001 until an approved '
            'production-supported transport and device-trust implementation '
            'replaces the current FlutterFire Windows path.',
      ),
      _ => ProductionPlatformPolicy(
        platform: platform,
        isSupported: false,
        allowsPointOfSale: false,
        blockReason:
            '${platform.name} is not an approved JCE POS production platform.',
      ),
    };
  }

  final AppClientPlatform platform;
  final bool isSupported;
  final bool allowsPointOfSale;
  final String? blockReason;

  void ensureSupported() {
    if (!isSupported) {
      throw UnsupportedError(blockReason ?? 'Unsupported production platform.');
    }
  }
}
