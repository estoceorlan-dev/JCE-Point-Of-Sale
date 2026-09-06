import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/database_provider.dart';
import 'package:jce_pos/core/config/app_config.dart';
import 'package:jce_pos/core/config/app_environment.dart';
import 'package:jce_pos/core/services/firebase_initialization_service.dart';
import 'package:jce_pos/core/startup/app_initialization_service.dart';
import 'package:jce_pos/core/startup/app_startup.dart';

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());
  const testConfig = AppConfig(
    environment: AppEnvironment.development,
    enableDemoAuth: true,
    enableDiagnostics: true,
    demoBranchId: 'test-branch',
  );

  testWidgets('starts the login shell when initialization succeeds', (
    tester,
  ) async {
    final initializer = _FakeInitializationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
          appDatabaseProvider.overrideWithValue(database),
          firebaseInitializationServiceProvider.overrideWithValue(initializer),
        ],
        child: const AppStartup(),
      ),
    );
    await tester.pumpAndSettle();

    expect(initializer.calls, 1);
    expect(find.text('Sign in to your workspace'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows a controlled error and can retry initialization', (
    tester,
  ) async {
    final initializer = _FakeInitializationService(failuresRemaining: 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
          appDatabaseProvider.overrideWithValue(database),
          firebaseInitializationServiceProvider.overrideWithValue(initializer),
        ],
        child: const AppStartup(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('JCE POS could not start'), findsOneWidget);
    expect(find.text('Retry initialization'), findsOneWidget);

    await tester.tap(find.text('Retry initialization'));
    await tester.pumpAndSettle();

    expect(initializer.calls, 2);
    expect(find.text('Sign in to your workspace'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _FakeInitializationService implements AppInitializationService {
  _FakeInitializationService({this.failuresRemaining = 0});

  int failuresRemaining;
  int calls = 0;

  @override
  Future<void> initialize(AppConfig config) async {
    calls += 1;
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('Simulated initialization failure.');
    }
  }
}
