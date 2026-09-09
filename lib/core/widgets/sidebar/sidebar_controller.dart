import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Separate initial states keep compact navigation closed on first display.
final sidebarControllerProvider = NotifierProvider.autoDispose
    .family<SidebarController, bool, bool>(SidebarController.new);

class SidebarController extends AutoDisposeFamilyNotifier<bool, bool> {
  static const autoCollapseDelay = Duration(seconds: 10);

  Timer? _collapseTimer;

  @override
  bool build(bool initiallyExpanded) {
    ref.onDispose(() => _collapseTimer?.cancel());
    if (initiallyExpanded) {
      _startCountdown();
    }
    return initiallyExpanded;
  }

  void toggle() => setExpanded(!state);

  void close() => setExpanded(false);

  /// Restarts auto-collapse from the user's most recent sidebar interaction.
  void registerInteraction() {
    if (state) {
      _startCountdown();
    }
  }

  void setExpanded(bool expanded) {
    if (state == expanded) return;
    _collapseTimer?.cancel();
    state = expanded;
    if (expanded) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(autoCollapseDelay, close);
  }
}
