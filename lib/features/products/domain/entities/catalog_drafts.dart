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
