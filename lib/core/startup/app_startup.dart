import 'dart:async';
import 'package:flutter/foundation.dart';
import '../sync/node_queue_recovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../features/auth/presentation/providers/native_auth_providers.dart';
import '../config/app_config.dart';
import '../config/production_platform_policy.dart';
import '../logger/app_logger.dart';
import '../services/firebase_initialization_service.dart';
import '../theme/app_theme.dart';
import 'startup_failure_page.dart';

class AppStartup extends ConsumerStatefulWidget {
  const AppStartup({super.key});

  @override
  ConsumerState<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<AppStartup> {
  Object? _initializationError;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const _StartupLoadingApp();
    }

    if (_initializationError != null) {
      return StartupFailurePage(onRetry: _initialize);
    }

    return const JcePosApp();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _initializationError = null;
        _isInitializing = true;
      });
    }

    try {
      final config = ref.read(appConfigProvider);
      ref.read(productionPlatformPolicyProvider).ensureSupported();
      if (config.useNodeBackend) {
        await ref.read(installationBindingProvider).initialize();
        if (!kIsWeb) unawaited(ref.read(nodeQueueRecoveryProvider).recover());
      } else {
        await ref
            .read(firebaseInitializationServiceProvider)
            .initialize(config);
      }
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'Application initialization failed.',
            scope: 'startup',
            error: error,
            stackTrace: stackTrace,
          );
      if (mounted) {
        setState(() {
          _initializationError = error;
          _isInitializing = false;
        });
      }
    }
  }
}

class _StartupLoadingApp extends StatelessWidget {
  const _StartupLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
