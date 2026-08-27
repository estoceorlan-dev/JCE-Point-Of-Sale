class ProductQuery {
  const ProductQuery({
    this.search = '',
    this.categoryId,
    this.includeArchived = false,
    this.offset = 0,
    this.pageSize = 30,
  });

  final String search;
  final String? categoryId;
  final bool includeArchived;
  final int offset;
  final int pageSize;

  ProductQuery copyWith({
    String? search,
    String? categoryId,
    bool clearCategory = false,
    bool? includeArchived,
    int? offset,
    int? pageSize,
  }) {
    return ProductQuery(
      search: search ?? this.search,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      includeArchived: includeArchived ?? this.includeArchived,
      offset: offset ?? this.offset,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}
