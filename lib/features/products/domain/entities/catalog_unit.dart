class CatalogUnit {
  const CatalogUnit({
    required this.id,
    required this.code,
    required this.name,
    required this.abbreviation,
    required this.allowsFractional,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String abbreviation;
  final bool allowsFractional;
  final bool isActive;
}
