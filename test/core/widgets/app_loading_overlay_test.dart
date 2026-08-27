import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/widgets/app_loading_overlay.dart';

void main() {
  testWidgets('blocks interaction and displays a loading message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TextButton(onPressed: null, child: Text('Background action')),
              AppLoadingOverlay(message: 'Signing you in...'),
            ],
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(AppLoadingOverlay),
        matching: find.byType(ModalBarrier),
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Signing you in...'), findsOneWidget);
  });
}
