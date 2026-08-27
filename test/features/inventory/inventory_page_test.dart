import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/inventory/presentation/pages/inventory_page.dart';
import 'package:jce_pos/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:jce_pos/shared/providers/app_providers.dart';
import 'package:jce_pos/shared/utils/formatters.dart';

void main() {
  testWidgets('inventory workspace exposes balances, history, and counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessContextProvider.overrideWithValue(null),
          activeInventorySessionProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: Scaffold(body: InventoryPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Balances'), findsOneWidget);
    expect(find.text('Movement history'), findsOneWidget);
    expect(find.text('Stock counts'), findsOneWidget);
    expect(
      find.text(
        'No balance records yet. Post an opening balance or adjustment to begin.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Movement history'));
    await tester.pumpAndSettle();
    expect(find.text('No inventory movements recorded yet.'), findsOneWidget);

    await tester.tap(find.text('Stock counts'));
    await tester.pumpAndSettle();
    expect(find.text('No stock counts have been started.'), findsOneWidget);
  });

  test('quantity formatting preserves integer thousandths', () {
    expect(Formatters.quantityMilli(1250), '1.25');
    expect(Formatters.quantityMilli(-1001), '-1.001');
    expect(Formatters.parseQuantityMilli('1.250'), 1250);
    expect(Formatters.parseQuantityMilli('0.001'), 1);
    expect(Formatters.parseQuantityMilli('1.0009'), isNull);
  });
}
