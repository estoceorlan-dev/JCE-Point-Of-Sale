import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/branches/domain/entities/branch_profile.dart';
import 'package:jce_pos/features/branches/domain/entities/philippine_address_catalog.dart';
import 'package:jce_pos/features/branches/presentation/providers/branches_providers.dart';
import 'package:jce_pos/features/branches/presentation/widgets/branch_form_dialog.dart';

void main() {
  testWidgets('selects an offline Philippine branch address', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const catalog = PhilippineAddressCatalog(
      country: 'Philippines',
      timezone: 'Asia/Manila',
      release: '2Q 2026',
      areas: [
        PhilippineAddressArea(
          name: 'Cebu',
          localities: [
            PhilippineLocality(code: '0702201000', name: 'Alcantara'),
            PhilippineLocality(code: '0702223000', name: 'Danao City'),
          ],
        ),
      ],
    );
    BranchDraft? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          philippineAddressCatalogProvider.overrideWith((ref) => catalog),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showDialog<BranchDraft>(
                      context: context,
                      builder: (context) => const BranchFormDialog(),
                    );
                  },
                  child: const Text('Open branch form'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open branch form'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('branch-timezone-dropdown')),
      findsOneWidget,
    );
    expect(find.text('Asia/Manila (Philippine Time)'), findsOneWidget);
    expect(find.text('Philippine address · PSGC 2Q 2026'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'DAN');
    await tester.enterText(find.byType(TextFormField).at(1), 'Danao');

    await tester.tap(
      find.byKey(const ValueKey('branch-province-dropdown-null')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cebu').last);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(
      find.byKey(const ValueKey('branch-city-dropdown-Cebu-null')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Alcantara').last);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.widgetWithText(FilledButton, 'Add branch'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(result, isNotNull);
    expect(result!.timezone, 'Asia/Manila');
    expect(result!.province, 'Cebu');
    expect(result!.city, 'Alcantara');
    expect(tester.takeException(), isNull);
  });
}
