enum PriceScope {
  organization,
  branch;

  static PriceScope fromBranchId(String? branchId) {
    return branchId == null ? PriceScope.organization : PriceScope.branch;
  }
}

class ProductPrice {
  const ProductPrice({
    required this.id,
    required this.scope,
    required this.unitPriceMinor,
    required this.effectiveFrom,
    this.branchId,
    this.effectiveTo,
  });

  final String id;
  final PriceScope scope;
  final String? branchId;
  final int unitPriceMinor;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
}

class ProductPriceDraft {
  const ProductPriceDraft({
    required this.scope,
    required this.unitPriceMinor,
    this.branchId,
    this.effectiveFrom,
  });

  final PriceScope scope;
  final String? branchId;
  final int unitPriceMinor;
  final DateTime? effectiveFrom;
}
