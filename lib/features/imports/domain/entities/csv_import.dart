enum CsvImportKind {
  catalog(
    'Catalog',
    'sku,name,unit_code,price,category,tax_code,barcodes,primary_barcode,description',
  ),
  openingStock('Opening stock', 'sku,location_code,quantity');

  const CsvImportKind(this.label, this.headers);
  final String label;
  final String headers;
  String get template => '$headers\r\n';
}

class CsvImportRow {
  const CsvImportRow({
    required this.number,
    required this.sku,
    required this.action,
    required this.errors,
  });
  final int number;
  final String sku;
  final String action;
  final List<String> errors;
}

class CsvImportPreview {
  const CsvImportPreview({
    required this.kind,
    required this.source,
    required this.rows,
    required this.revision,
  });
  final CsvImportKind kind;
  final String source;
  final List<CsvImportRow> rows;
  final String revision;
  bool get canConfirm =>
      rows.isNotEmpty && rows.every((row) => row.errors.isEmpty);
}
