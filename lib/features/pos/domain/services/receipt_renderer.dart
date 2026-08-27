import '../../../../shared/utils/formatters.dart';
import '../entities/sale.dart';

class ReceiptDocument {
  const ReceiptDocument({required this.plainText});

  final String plainText;
}

abstract interface class ReceiptRenderer {
  ReceiptDocument render(SaleRecord sale);
}

class PlainTextReceiptRenderer implements ReceiptRenderer {
  const PlainTextReceiptRenderer();

  @override
  ReceiptDocument render(SaleRecord sale) {
    final lines = <String>[
      'JCE General Merchandise',
      'Receipt ${sale.receiptNumber}',
      'Register: ${sale.registerName}',
      'Date: ${sale.completedAt.toLocal()}',
      '--------------------------------',
      for (final item in sale.items) ...[
        '${item.productName} (${item.sku})',
        '${_quantity(item.quantityMilli)} x ${Formatters.currencyMinor(item.unitPriceMinor)}  ${Formatters.currencyMinor(item.totalAmountMinor)}',
        if (item.discountAmountMinor > 0)
          '  Discount: -${Formatters.currencyMinor(item.discountAmountMinor)}',
      ],
      '--------------------------------',
      'Subtotal: ${Formatters.currencyMinor(sale.subtotalMinor)}',
      'Discount: -${Formatters.currencyMinor(sale.discountMinor)}',
      'Tax: ${Formatters.currencyMinor(sale.taxMinor)}',
      'TOTAL: ${Formatters.currencyMinor(sale.totalMinor)}',
      for (final payment in sale.payments)
        '${payment.method.label}: ${Formatters.currencyMinor(payment.tenderedAmountMinor)}',
      'Change: ${Formatters.currencyMinor(sale.changeMinor)}',
      '--------------------------------',
      'Thank you!',
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
