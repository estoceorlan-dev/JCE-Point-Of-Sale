abstract final class CatalogNormalizer {
  static String search(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String sku(String value) => search(value).toUpperCase();

  static String barcode(String value) {
    return value.trim().replaceAll(RegExp(r'[\s-]+'), '');
  }
}
