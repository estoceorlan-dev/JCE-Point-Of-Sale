import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/shifts/domain/entities/cash_shift.dart';
import 'package:jce_pos/features/shifts/domain/entities/register.dart';
import 'package:jce_pos/features/shifts/presentation/pages/shift_page.dart';
import 'package:jce_pos/features/shifts/presentation/providers/shift_providers.dart';

void main() {
  testWidgets('shift workspace shows register assignment and recovery state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDeviceIdProvider.overrideWith((ref) async => 'device-a'),
          registersProvider.overrideWith(
            (ref) => Stream.value(const [
              Register(
                id: 'register',
                organizationId: 'organization',
                branchId: 'branch',
                code: 'REG-01',
                name: 'Front register',
                assignedDeviceId: 'device-a',
                isActive: true,
                version: 1,
              ),
            ]),
          ),
          activeShiftProvider.overrideWith((ref) => Stream.value(null)),
          recentShiftsProvider.overrideWith(
            (ref) => Stream.value(const <CashShift>[]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ShiftPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Register & shift'), findsOneWidget);
    expect(find.text('Branch registers'), findsOneWidget);
    expect(find.text('REG-01 • Front register'), findsOneWidget);
    expect(find.text('Assigned to this device'), findsOneWidget);
    expect(find.text('Recent shifts'), findsOneWidget);
  });
}
