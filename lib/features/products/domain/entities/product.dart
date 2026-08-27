import 'product_price.dart';

class Product {
  const Product({
    required this.id,
    required this.organizationId,
    required this.sku,
    required this.name,
    required this.unitId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.taxCategoryId,
    this.description,
    this.barcodes = const <String>[],
    this.imagePaths = const <String>[],
    this.activePrice,
  });

  final String id;
  final String organizationId;
  final String sku;
  final String name;
  final String unitId;
  final String? categoryId;
  final String? taxCategoryId;
  final String? description;
  final List<String> barcodes;
  final List<String> imagePaths;
  final ProductPrice? activePrice;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
