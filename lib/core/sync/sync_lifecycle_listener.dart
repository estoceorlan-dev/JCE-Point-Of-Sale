import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_controller.dart';

class SyncLifecycleListener extends ConsumerStatefulWidget {
  const SyncLifecycleListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleListener> createState() =>
      _SyncLifecycleListenerState();
}

class _SyncLifecycleListenerState extends ConsumerState<SyncLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncStateProvider.notifier).onForeground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
