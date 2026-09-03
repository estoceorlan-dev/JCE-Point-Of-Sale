import '../../../../shared/utils/formatters.dart';
import '../entities/sale.dart';
import '../entities/sale_correction.dart';

class ReceiptDocument {
  const ReceiptDocument({required this.plainText});

  final String plainText;
}

abstract interface class ReceiptRenderer {
  ReceiptDocument render(SaleRecord sale);
}

class PlainTextReceiptRenderer implements ReceiptRenderer {
  const PlainTextReceiptRenderer({
    this.header = 'JCE General Merchandise',
    this.footer = 'Thank you!',
    this.showTaxBreakdown = true,
    this.paperWidthCharacters = 42,
  });

  final String header;
  final String footer;
  final bool showTaxBreakdown;
  final int paperWidthCharacters;

  @override
  ReceiptDocument render(SaleRecord sale) {
    final separator = List.filled(paperWidthCharacters, '-').join();
    final lines = <String>[
      header,
      'Receipt ${sale.receiptNumber}',
      'Register: ${sale.registerName}',
      'Date: ${sale.completedAt.toLocal()}',
      if (sale.customerDisplayName case final customer?) 'Customer: $customer',
      separator,
      for (final item in sale.items) ...[
        '${item.productName} (${item.sku})',
        '${_quantity(item.quantityMilli)} x ${Formatters.currencyMinor(item.unitPriceMinor)}  ${Formatters.currencyMinor(item.totalAmountMinor)}',
        if (item.discountAmountMinor > 0)
          '  Discount: -${Formatters.currencyMinor(item.discountAmountMinor)}',
      ],
      separator,
      if (showTaxBreakdown) ...[
        'Subtotal: ${Formatters.currencyMinor(sale.subtotalMinor)}',
        'Discount: -${Formatters.currencyMinor(sale.discountMinor)}',
        'Tax: ${Formatters.currencyMinor(sale.taxMinor)}',
      ],
      'TOTAL: ${Formatters.currencyMinor(sale.totalMinor)}',
      for (final payment in sale.payments)
        '${payment.method.label}: ${Formatters.currencyMinor(payment.tenderedAmountMinor)}',
      'Change: ${Formatters.currencyMinor(sale.changeMinor)}',
      separator,
      if (footer.isNotEmpty) footer,
    ];
    return ReceiptDocument(plainText: lines.join('\n'));
  }
}

abstract interface class CorrectionReceiptRenderer {
  ReceiptDocument render({
    required SaleRecord sale,
    required SaleCorrectionRecord correction,
  });
}

class PlainTextCorrectionReceiptRenderer implements CorrectionReceiptRenderer {
  const PlainTextCorrectionReceiptRenderer();

  @override
  ReceiptDocument render({
    required SaleRecord sale,
    required SaleCorrectionRecord correction,
  }) {
    final lines = <String>[
      'JCE General Merchandise',
      '${correction.type.label} ${correction.returnNumber}',
      'Status: ${correction.status}',
      'Original receipt: ${sale.receiptNumber}',
      'Date: ${correction.completedAt.toLocal()}',
      'Reason: ${correction.reasonCode}',
      if (correction.notes case final notes?) 'Notes: $notes',
      '--------------------------------',
      for (final item in correction.items) ...[
        '${item.productName} (${item.disposition.label})',
        '${_quantity(item.quantityMilli)}  ${Formatters.currencyMinor(item.totalMinor)}',
      ],
      '--------------------------------',
      'Subtotal: ${Formatters.currencyMinor(correction.subtotalMinor)}',
      'Discount: -${Formatters.currencyMinor(correction.discountMinor)}',
      'Tax: ${Formatters.currencyMinor(correction.taxMinor)}',
      'REFUND: ${Formatters.currencyMinor(correction.totalMinor)}',
      for (final refund in correction.refunds)
        '${refund.method.label}: ${Formatters.currencyMinor(refund.amountMinor)}',
      if (correction.approvedByUserId case final manager?)
        'Approved by: $manager',
      '--------------------------------',
      'Correction records do not alter the original receipt.',
    ];
    return ReceiptDocument(plainText: lines.join('\n'));
  }
}

String _quantity(int milli) {
  final whole = milli ~/ 1000;
  final fraction = (milli % 1000).toString().padLeft(3, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
}
