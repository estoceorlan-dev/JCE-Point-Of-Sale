import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/utils/currency_text_input_formatter.dart';

void main() {
  const formatter = CurrencyTextInputFormatter();

  test('accepts editable unsigned currency with at most two decimals', () {
    const empty = TextEditingValue.empty;
    final twelve = formatter.formatEditUpdate(
      empty,
      const TextEditingValue(text: '12.'),
    );

    expect(twelve.text, '12.');
    expect(
      formatter
          .formatEditUpdate(twelve, const TextEditingValue(text: '12.34'))
          .text,
      '12.34',
    );
    expect(
      formatter
          .formatEditUpdate(twelve, const TextEditingValue(text: '12.345'))
          .text,
      '12.',
    );
    expect(
      formatter
          .formatEditUpdate(twelve, const TextEditingValue(text: '-12'))
          .text,
      '12.',
    );
    expect(
      formatter
          .formatEditUpdate(twelve, const TextEditingValue(text: 'cash'))
          .text,
      '12.',
    );
  });
}
