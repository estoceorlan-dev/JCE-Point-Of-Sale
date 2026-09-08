import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/hardware/domain/entities/register_hardware_profile.dart';
import 'package:jce_pos/features/pos/presentation/widgets/terminal_status_strip.dart';
import 'package:jce_pos/shared/models/sync_state.dart';

void main() {
  testWidgets('offline status reports every locally queued condition', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SyncState(
          status: SyncStatus.offline,
          pendingChanges: 2,
          retryingChanges: 1,
          failedChanges: 1,
          conflicts: 2,
        ),
        textScale: 1.5,
      ),
    );

    expect(
      find.text('Offline · 3 queued · 1 failed · 2 conflicts'),
      findsOneWidget,
    );
    expect(find.text('Keyboard wedge'), findsOneWidget);
    expect(find.text('Screen / PDF only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed and healthy sync states are distinct', (tester) async {
    await tester.pumpWidget(
      _host(
        const SyncState(
          status: SyncStatus.failed,
          pendingChanges: 4,
          failedChanges: 2,
        ),
      ),
    );
    expect(
      find.text('Sync needs attention · 4 queued · 2 failed'),
      findsOneWidget,
    );

    await tester.pumpWidget(_host(const SyncState(status: SyncStatus.idle)));
    expect(find.text('Synced'), findsOneWidget);

    await tester.pumpWidget(
      _host(const SyncState(status: SyncStatus.idle, failedChanges: 1)),
    );
    expect(find.text('Saved locally · 1 failed'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
  });
}

Widget _host(SyncState state, {double textScale = 1}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: TerminalStatusStrip(
            branchName: 'A very long branch name for compact terminals',
            registerName: 'Register 1',
            cashierName: 'Cashier Name',
            shiftOpen: true,
            syncState: state,
            scannerType: BarcodeScannerType.keyboardWedge,
            printerType: ReceiptPrinterType.screen,
          ),
        ),
      ),
    ),
  );
}
