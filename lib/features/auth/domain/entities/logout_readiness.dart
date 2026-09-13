class LogoutReadiness {
  const LogoutReadiness({
    required this.openShiftCount,
    required this.checkoutRecoveryCount,
    required this.pendingOperationalCommandCount,
  });

  final int openShiftCount;
  final int checkoutRecoveryCount;
  final int pendingOperationalCommandCount;

  bool get canLogout =>
      openShiftCount == 0 &&
      checkoutRecoveryCount == 0 &&
      pendingOperationalCommandCount == 0;

  String get blockerMessage {
    final blockers = <String>[
      if (openShiftCount > 0) 'close the open cashier shift',
      if (checkoutRecoveryCount > 0) 'finish the payment recovery',
      if (pendingOperationalCommandCount > 0)
        'synchronize or resolve $pendingOperationalCommandCount operational command(s)',
    ];
    return 'Logout is blocked: ${blockers.join(', ')}.';
  }
}
