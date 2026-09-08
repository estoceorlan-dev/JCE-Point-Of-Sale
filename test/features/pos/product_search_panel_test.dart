import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_product.dart';
import 'package:jce_pos/features/pos/presentation/widgets/product_search_panel.dart';

void main() {
  testWidgets('product browser exposes loading and empty states', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller, const AsyncLoading()));
    expect(find.byKey(const Key('pos-products-loading')), findsOneWidget);

    await tester.pumpWidget(
      _host(controller, const AsyncData(<SaleProduct>[])),
    );
    await tester.pump();
    expect(find.byKey(const Key('pos-products-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact product error preserves cart message and retries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var retries = 0;

    await tester.pumpWidget(
      _host(
        controller,
        AsyncError<List<SaleProduct>>(
          StateError('offline'),
          StackTrace.current,
        ),
        textScale: 1.5,
        onRetry: () => retries++,
      ),
    );
    expect(find.byKey(const Key('pos-products-error')), findsOneWidget);
    expect(
      find.textContaining('saved cart is still available'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('retry-products-button')));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(
  TextEditingController controller,
  AsyncValue<List<SaleProduct>> products, {
  double textScale = 1,
  VoidCallback? onRetry,
}) {
  return ProviderScope(
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 640,
          child: ProductSearchPanel(
            searchController: controller,
            products: products,
            onSearchChanged: (_) {},
            onSubmitted: (_) {},
            onRetry: onRetry,
            fillHeight: true,
          ),
        ),
      ),
    ),
  );
}
