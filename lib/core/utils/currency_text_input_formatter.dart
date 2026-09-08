import 'package:flutter/services.dart';

/// Accepts unsigned currency text with at most two fractional digits.
///
/// Empty input and a trailing decimal point remain valid while the cashier is
/// editing. Business validation still converts the final value to minor units.
class CurrencyTextInputFormatter extends TextInputFormatter {
  const CurrencyTextInputFormatter();

  static final RegExp _validInput = RegExp(r'^\d*(?:\.\d{0,2})?$');

  static bool isValid(String value) => _validInput.hasMatch(value);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return isValid(newValue.text) ? newValue : oldValue;
  }
}
