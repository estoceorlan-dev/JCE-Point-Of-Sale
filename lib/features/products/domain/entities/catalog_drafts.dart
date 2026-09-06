class CategoryDraft {
  const CategoryDraft({required this.name});

  final String name;
}

class UnitDraft {
  const UnitDraft({
    required this.code,
    required this.name,
    required this.abbreviation,
    this.allowsFractional = false,
  });

  final String code;
  final String name;
  final String abbreviation;
  final bool allowsFractional;
}

class TaxCategoryDraft {
  const TaxCategoryDraft({
    required this.code,
    required this.name,
    required this.rateBasisPoints,
    this.isInclusive = true,
  });

  final String code;
  final String name;
  final int rateBasisPoints;
  final bool isInclusive;

  TaxCategoryDraft normalized() => TaxCategoryDraft(
    code: code.trim().toUpperCase(),
    name: name.trim(),
    rateBasisPoints: rateBasisPoints,
    isInclusive: isInclusive,
  );
}
