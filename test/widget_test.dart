import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/app.dart';
import 'package:jce_pos/core/config/app_config.dart';
import 'package:jce_pos/core/config/app_environment.dart';
import 'package:jce_pos/core/database/app_database_config.dart';
import 'package:jce_pos/core/database/database_provider.dart';

void main() {
  const testConfig = AppConfig(
    environment: AppEnvironment.development,
    enableDemoAuth: true,
    enableDiagnostics: true,
    demoBranchId: 'test-branch',
  );
  Widget buildTestApp() => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(testConfig),
      appDatabaseConfigProvider.overrideWithValue(
        AppDatabaseConfig(executor: NativeDatabase.memory()),
      ),
    ],
    child: const JcePosApp(),
  );

  testWidgets('JCE POS starts on the login page', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(
      find.image(const AssetImage('assets/images/jce_logo.jpg')),
      findsOneWidget,
    );
    expect(find.text('JCE'), findsNothing);
    expect(find.text('Dry Goods Trading'), findsNothing);
    expect(find.text('Sign in to your workspace'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.byKey(const Key('login-card')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('hardcoded cashier login opens a role shell', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'cashier@jce.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Cashier Staff'), findsOneWidget);
    expect(find.text('Cashier'), findsWidgets);
    expect(find.text('POS'), findsWidgets);
    expect(find.text('Reports'), findsNothing);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to log out of your account?'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing);
    expect(find.text('Dashboard'), findsWidgets);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
