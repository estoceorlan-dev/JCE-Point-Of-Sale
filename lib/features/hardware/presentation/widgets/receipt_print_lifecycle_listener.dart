import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_clock.dart';
import '../providers/hardware_providers.dart';

class ReceiptPrintLifecycleListener extends ConsumerStatefulWidget {
  const ReceiptPrintLifecycleListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReceiptPrintLifecycleListener> createState() =>
      _ReceiptPrintLifecycleListenerState();
}

class _ReceiptPrintLifecycleListenerState
    extends ConsumerState<ReceiptPrintLifecycleListener>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_recoverAndProcess());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_process()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_process());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _recoverAndProcess() async {
    final repository = ref.read(posHardwareRepositoryProvider);
    final now = ref.read(appClockProvider).nowUtc();
    await repository.recoverInterruptedJobs(now: now);
    await _process();
  }

  Future<void> _process() async {
    if (_processing || !mounted) return;
    _processing = true;
    try {
      await ref.read(receiptPrintQueueProcessorProvider).processDue();
    } finally {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
