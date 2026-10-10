import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/error/failure.dart';
import 'package:jce_pos/core/error/result.dart';
import 'package:jce_pos/features/auth/domain/services/account_action_service.dart';
import 'package:jce_pos/features/auth/presentation/controllers/account_action_controller.dart';
import 'package:jce_pos/features/auth/presentation/widgets/account_action_panel.dart';

void main() {
  testWidgets(
    'activation validates passwords and clears one-time token after completion',
    (tester) async {
      final service = _Actions();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [accountActionServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AccountActionPanel()),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Activate account or recover password'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Set password'));
      await tester.tap(find.text('Set password'));
      await tester.pump();
      expect(service.calls, 0);
      expect(find.text('Enter the issued token.'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'a' * 43);
      await tester.enterText(fields.at(1), 'strong-password');
      await tester.enterText(fields.at(2), 'does-not-match');
      await tester.ensureVisible(find.text('Set password'));
      await tester.tap(find.text('Set password'));
      await tester.pump();
      expect(service.calls, 0);
      expect(find.text('Passwords must match.'), findsOneWidget);
      await tester.enterText(fields.at(2), 'strong-password');
      await tester.ensureVisible(find.text('Set password'));
      await tester.tap(find.text('Set password'));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(service.recovery, false);
      expect(
        find.text('Password saved. Sign in with your email and new password.'),
        findsOneWidget,
      );
      for (final field in tester.widgetList<TextFormField>(fields)) {
        expect(field.controller!.text, isEmpty);
      }
    },
  );
}

class _Actions implements AccountActionService {
  int calls = 0;
  bool? recovery;
  @override
  Future<Result<IssuedAccountAction, Failure>> issue({
    required String userId,
    required bool recovery,
  }) async => throw UnimplementedError();
  @override
  Future<Result<void, Failure>> complete({
    required String token,
    required String password,
    required bool recovery,
  }) async {
    calls++;
    this.recovery = recovery;
    return const Result.success(null);
  }
}
