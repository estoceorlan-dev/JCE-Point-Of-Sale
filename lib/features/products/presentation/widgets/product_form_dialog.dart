import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/entities/catalog_category.dart';
import '../../domain/entities/catalog_tax_category.dart';
import '../../domain/entities/catalog_unit.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_draft.dart';
import '../../domain/entities/product_price.dart';
import '../../domain/entities/product_summary.dart';
import '../../domain/value_objects/minor_unit_parser.dart';
import '../controllers/product_mutation_controller.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.categories,
    required this.units,
    required this.taxCategories,
    this.product,
    this.summary,
  });

  final List<CatalogCategory> categories;
  final List<CatalogUnit> units;
  final List<CatalogTaxCategory> taxCategories;
  final Product? product;
  final ProductSummary? summary;

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _barcodesController;
  late final TextEditingController _priceController;
  late final TextEditingController _imagePathsController;
  String? _categoryId;
  String? _taxCategoryId;
  String? _unitId;
  PriceScope _priceScope = PriceScope.organization;
  String? _error;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _skuController = TextEditingController(text: product?.sku);
    _nameController = TextEditingController(text: product?.name);
    _descriptionController = TextEditingController(text: product?.description);
    _barcodesController = TextEditingController(
      text: product?.barcodes.join(', '),
    );
    final activePrice = product?.activePrice;
    _priceController = TextEditingController(
      text: MinorUnitParser.format(
        activePrice?.unitPriceMinor ?? widget.summary?.unitPriceMinor ?? 0,
      ),
    );
    _imagePathsController = TextEditingController(
      text: product?.imagePaths.join(', '),
    );
    final productCategoryId = product?.categoryId;
    _categoryId =
        widget.categories.any(
          (category) => category.id == productCategoryId && category.isActive,
        )
        ? productCategoryId
        : null;
    final productTaxCategoryId = product?.taxCategoryId;
    _taxCategoryId =
        widget.taxCategories.any(
          (taxCategory) =>
              taxCategory.id == productTaxCategoryId && taxCategory.isActive,
        )
        ? productTaxCategoryId
        : null;
    _priceScope = activePrice?.scope ?? PriceScope.organization;
    final productUnitId = product?.unitId;
    _unitId =
        widget.units.any((unit) => unit.id == productUnitId && unit.isActive)
        ? productUnitId
        : (widget.units.isEmpty ? null : widget.units.first.id);
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _barcodesController.dispose();
    _priceController.dispose();
    _imagePathsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(productMutationControllerProvider).isLoading;
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit product' : 'Create product',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _skuController,
                                decoration: const InputDecoration(
                                  labelText: 'SKU *',
                                ),
                                validator: _required,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Product name *',
                                ),
                                validator: _required,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: _categoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Uncategorized'),
                                  ),
                                  ...widget.categories.map(
                                    (category) => DropdownMenuItem<String?>(
                                      value: category.id,
                                      child: Text(category.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) => _categoryId = value,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _unitId,
                                decoration: const InputDecoration(
                                  labelText: 'Unit *',
                                ),
                                items: widget.units
                                    .map(
                                      (unit) => DropdownMenuItem(
                                        value: unit.id,
                                        child: Text(
                                          '${unit.name} (${unit.abbreviation})',
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) =>
                                    setState(() => _unitId = value),
                                validator: (value) =>
                                    value == null ? 'Select a unit.' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String?>(
                          initialValue: _taxCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Tax category',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No tax category'),
                            ),
                            ...widget.taxCategories.map(
                              (taxCategory) => DropdownMenuItem<String?>(
                                value: taxCategory.id,
                                child: Text(
                                  '${taxCategory.name} '
                                  '(${_formatTaxRate(taxCategory.rateBasisPoints)}%)',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) => _taxCategoryId = value,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _barcodesController,
                          decoration: const InputDecoration(
                            labelText: 'Barcodes',
                            helperText:
                                'Separate multiple barcodes with commas.',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Unit price (PHP) *',
                                  prefixText: '₱ ',
                                ),
                                validator: (value) {
                                  return MinorUnitParser.tryParse(
                                            value ?? '',
                                          ) ==
                                          null
                                      ? 'Enter a valid non-negative amount.'
                                      : null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Branch-specific price'),
                                subtitle: const Text(
                                  'Overrides the organization price here.',
                                ),
                                value: _priceScope == PriceScope.branch,
                                onChanged: (value) => setState(() {
                                  _priceScope = value
                                      ? PriceScope.branch
                                      : PriceScope.organization;
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _imagePathsController,
                          decoration: const InputDecoration(
                            labelText: 'Local image paths',
                            helperText:
                                'Optional; comma-separated images are queued for upload.',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: isSaving ? null : _submit,
                      icon: isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isEditing ? 'Save changes' : 'Create product',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required.'
        : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final priceMinor = MinorUnitParser.tryParse(_priceController.text)!;
    final branchId = ref.read(currentBranchIdProvider);
    final draft = ProductDraft(
      sku: _skuController.text,
      name: _nameController.text,
      unitId: _unitId!,
      categoryId: _categoryId,
      taxCategoryId: _taxCategoryId,
      description: _descriptionController.text,
      barcodes: _splitValues(_barcodesController.text),
      imagePaths: _splitValues(_imagePathsController.text),
      unitPriceMinor: priceMinor,
      priceScope: _priceScope,
      priceBranchId: _priceScope == PriceScope.branch ? branchId : null,
    );
    final controller = ref.read(productMutationControllerProvider.notifier);
    final result = _isEditing
        ? await controller.updateProduct(
            productId: widget.product!.id,
            draft: draft,
          )
        : await controller.createProduct(draft);
    if (!mounted) {
      return;
    }
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }

  List<String> _splitValues(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _formatTaxRate(int basisPoints) {
    final whole = basisPoints ~/ 100;
    final fraction = basisPoints.remainder(100);
    return fraction == 0
        ? whole.toString()
        : '$whole.${fraction.toString().padLeft(2, '0')}';
  }
}
