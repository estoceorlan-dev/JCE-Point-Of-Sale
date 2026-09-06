import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/imports/domain/services/csv_document_parser.dart';
import 'package:jce_pos/features/products/domain/value_objects/minor_unit_parser.dart';

void main() {
  const parser = CsvDocumentParser();
  List<Map<String, String>> parse(String text, {int maximumRows = 10000}) =>
      parser.parse(
        text,
        requiredHeaders: {'sku', 'name'},
        allowedHeaders: {'sku', 'name'},
        maximumRows: maximumRows,
      );

  test('parses BOM, CRLF, quoted commas, newlines and escaped quotes', () {
    final rows = parse(
      '\uFEFFSKU,Name\r\nA,"Milk, full cream"\r\nB,"First\n""second"""\r\n',
    );
    expect(rows, [
      {'sku': 'A', 'name': 'Milk, full cream'},
      {'sku': 'B', 'name': 'First\n"second"'},
    ]);
  });
  test('rejects malformed quoting, encoding and column counts', () {
    for (final source in [
      'sku,name\nA,"Unclosed',
      'sku,name\nA,"Closed"garbage',
      'sku,name\nA,B,C',
      'sku,name\nA,\uFFFD',
      'sku,name\nA,\u0000',
    ]) {
      expect(() => parse(source), throwsFormatException, reason: source);
    }
  });
  test('validates duplicate, missing and unknown headers', () {
    for (final source in ['sku,sku\nA,B', 'sku,title\nA,B', ',name\nA,B']) {
      expect(() => parse(source), throwsFormatException);
    }
  });
  test('enforces row limit with and without trailing newline', () {
    expect(parse('sku,name\nA,One', maximumRows: 1), hasLength(1));
    expect(
      () => parse('sku,name\nA,One\nB,Two', maximumRows: 1),
      throwsFormatException,
    );
    expect(
      () => parse('sku,name\nA,One\nB,Two\n', maximumRows: 1),
      throwsFormatException,
    );
  });
  test(
    'rejects monetary values that cannot round-trip exactly through JSON',
    () {
      expect(MinorUnitParser.tryParse('9223372036854775807'), isNull);
      expect(MinorUnitParser.tryParse('112.50'), 11250);
    },
  );
}
