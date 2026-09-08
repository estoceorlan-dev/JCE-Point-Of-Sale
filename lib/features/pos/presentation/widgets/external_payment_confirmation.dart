import 'package:flutter/material.dart';

import '../../../../shared/utils/formatters.dart';

/// Cashier attestation only, never a provider authorization response.
class ExternalPaymentConfirmation extends StatelessWidget {
  const ExternalPaymentConfirmation({
    required this.methodLabel,
    required this.amountMinor,
    required this.confirmed,
    required this.onChanged,
    super.key,
  });

  final String methodLabel;
  final int amountMinor;
  final bool confirmed;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: confirmed,
      onChanged: onChanged == null
          ? null
          : (value) => onChanged!(value ?? false),
      title: Text(
        'I verified $methodLabel payment of '
        '${Formatters.currencyMinor(amountMinor)} was approved',
      ),
      subtitle: const Text(
        'Do not confirm pending, declined or cancelled payments. '
        'If saving the sale fails after approval, do not charge again; '
        'reconcile the existing payment first.',
      ),
    );
  }
}
