class CatalogTaxCategory {
  const CatalogTaxCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.rateBasisPoints,
    required this.isInclusive,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final int rateBasisPoints;
  final bool isInclusive;
  final bool isActive;
}
