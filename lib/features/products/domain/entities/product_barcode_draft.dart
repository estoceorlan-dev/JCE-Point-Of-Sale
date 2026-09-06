class ProductBarcodeDraft {
  const ProductBarcodeDraft({required this.value, this.isPrimary = false});
  final String value;
  final bool isPrimary;

  ProductBarcodeDraft normalized() =>
      ProductBarcodeDraft(value: value.trim(), isPrimary: isPrimary);

  ProductBarcodeDraft withPrimary(bool primary) =>
      ProductBarcodeDraft(value: value, isPrimary: primary);
}
