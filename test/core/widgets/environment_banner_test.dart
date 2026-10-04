import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/config/app_environment.dart';
import 'package:jce_pos/core/widgets/environment_banner.dart';

void main() {
  testWidgets('labels staging builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: EnvironmentBanner(
          environment: AppEnvironment.staging,
          child: SizedBox(),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Banner && widget.message == 'STAGING',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not label production builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: EnvironmentBanner(
          environment: AppEnvironment.production,
          child: Text('Production'),
        ),
      ),
    );

    expect(find.byType(Banner), findsNothing);
    expect(find.text('Production'), findsOneWidget);
  });
}
