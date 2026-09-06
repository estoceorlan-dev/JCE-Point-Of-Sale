import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/products/domain/entities/product_draft.dart';
import 'package:jce_pos/features/products/domain/entities/product_barcode_draft.dart';
import 'package:jce_pos/features/products/domain/use_cases/validate_product_use_case.dart';
import 'package:jce_pos/features/products/domain/value_objects/minor_unit_parser.dart';

void main() {
  const validate = ValidateProductUseCase();

  test('normalizes valid product input without using floating-point money', () {
    final result = validate(
      const ProductDraft(
        sku: ' sku-100 ',
        name: '  Sample Product  ',
        unitId: ' unit ',
        barcodes: [' 4800-1234 '],
        unitPriceMinor: 12999,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.sku, 'SKU-100');
    expect(result.valueOrNull?.name, 'Sample Product');
    expect(result.valueOrNull?.unitPriceMinor, 12999);
  });

  test('rejects negative prices and repeated normalized barcodes', () {
    final negativePrice = validate(
      const ProductDraft(
        sku: 'SKU-100',
        name: 'Sample Product',
        unitId: 'unit',
        unitPriceMinor: -1,
      ),
    );
    final repeatedBarcode = validate(
      const ProductDraft(
        sku: 'SKU-100',
        name: 'Sample Product',
        unitId: 'unit',
        barcodes: ['4800-1234', '48001234'],
        unitPriceMinor: 100,
      ),
    );

    expect(negativePrice.isFailure, isTrue);
    expect(repeatedBarcode.isFailure, isTrue);
  });

  test('minor-unit parser converts decimal text exactly', () {
    expect(MinorUnitParser.tryParse('1,299.95'), 129995);
    expect(MinorUnitParser.tryParse('10.1'), 1010);
    expect(MinorUnitParser.tryParse('10.001'), isNull);
  });

  test(
    'typed barcode drafts require exactly one primary and preserve selection',
    () {
      ProductDraft draft(List<ProductBarcodeDraft> barcodes) => ProductDraft(
        sku: 'SKU-100',
        name: 'Product',
        unitId: 'unit',
        unitPriceMinor: 100,
        barcodeDrafts: barcodes,
      );
      expect(
        validate(draft(const [ProductBarcodeDraft(value: '48001')])).isFailure,
        isTrue,
      );
      expect(
        validate(
          draft(const [
            ProductBarcodeDraft(value: '48001', isPrimary: true),
            ProductBarcodeDraft(value: '48002', isPrimary: true),
          ]),
        ).isFailure,
        isTrue,
      );
      final valid = validate(
        draft(const [
          ProductBarcodeDraft(value: '48001'),
          ProductBarcodeDraft(value: '48002', isPrimary: true),
        ]),
      );
      expect(valid.isSuccess, isTrue);
      expect(valid.valueOrNull!.barcodes, ['48002', '48001']);
    },
  );
}
