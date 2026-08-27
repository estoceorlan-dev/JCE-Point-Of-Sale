import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/products/domain/entities/catalog_unit.dart';
import 'package:jce_pos/features/products/domain/entities/catalog_tax_category.dart';
import 'package:jce_pos/features/products/domain/entities/product.dart';
import 'package:jce_pos/features/products/domain/entities/product_price.dart';
import 'package:jce_pos/features/products/presentation/widgets/product_form_dialog.dart';

void main() {
  testWidgets('product form exposes validation before persistence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProductFormDialog(
              categories: [],
              taxCategories: [],
              units: [
                CatalogUnit(
                  id: 'unit',
                  code: 'PC',
                  name: 'Piece',
                  abbreviation: 'pc',
                  allowsFractional: false,
                  isActive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create product').last);
    await tester.pump();

    expect(find.text('This field is required.'), findsNWidgets(2));
  });

  testWidgets('edit form restores tax and branch price scope', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 8, 23);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProductFormDialog(
              categories: const [],
              units: const [
                CatalogUnit(
                  id: 'unit',
                  code: 'PC',
                  name: 'Piece',
                  abbreviation: 'pc',
                  allowsFractional: false,
                  isActive: true,
                ),
              ],
              taxCategories: const [
                CatalogTaxCategory(
                  id: 'vat',
                  code: 'VAT12',
                  name: 'VAT 12%',
                  rateBasisPoints: 1200,
                  isInclusive: true,
                  isActive: true,
                ),
              ],
              product: Product(
                id: 'product',
                organizationId: 'organization',
                sku: 'SKU-001',
                name: 'Product',
                unitId: 'unit',
                taxCategoryId: 'vat',
                isActive: true,
                createdAt: now,
                updatedAt: now,
                activePrice: ProductPrice(
                  id: 'price',
                  scope: PriceScope.branch,
                  branchId: 'branch',
                  unitPriceMinor: 12500,
                  effectiveFrom: now,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VAT 12% (12%)'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.widgetWithText(TextFormField, '125.00'), findsOneWidget);
  });
}
