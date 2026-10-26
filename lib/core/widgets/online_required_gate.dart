import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/online_availability_service.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

class OnlineRequiredGate extends ConsumerStatefulWidget {
  const OnlineRequiredGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnlineRequiredGate> createState() => _OnlineRequiredGateState();
}

class _OnlineRequiredGateState extends ConsumerState<OnlineRequiredGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _available = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(appConfigProvider).onlineOnly) {
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_check()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(appConfigProvider).onlineOnly) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_available)
          ColoredBox(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Online connection required',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'This hosted deployment does not support offline operation. '
                          'Reconnect to the JCE service before continuing.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                            ),
                          ),
                          onPressed: _checking ? null : _check,
                          icon: _checking
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: const Text('Retry connection'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _check() async {
    if (_checking || !ref.read(appConfigProvider).onlineOnly) return;
    if (mounted) setState(() => _checking = true);
    final available = await ref
        .read(onlineAvailabilityServiceProvider)
        .isReady(ref.read(appConfigProvider));
    if (mounted) {
      setState(() {
        _available = available;
        _checking = false;
      });
    }
  }
}
