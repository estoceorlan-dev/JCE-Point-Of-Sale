import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/product_barcode_draft.dart';
import '../../domain/value_objects/catalog_normalizer.dart';

class ProductBarcodeEditor extends StatefulWidget {
  const ProductBarcodeEditor({
    super.key,
    required this.barcodes,
    required this.onChanged,
    this.enabled = true,
  });
  final List<ProductBarcodeDraft> barcodes;
  final ValueChanged<List<ProductBarcodeDraft>> onChanged;
  final bool enabled;
  @override
  State<ProductBarcodeEditor> createState() => _ProductBarcodeEditorState();
}

class _ProductBarcodeEditorState extends State<ProductBarcodeEditor> {
  final _entry = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  @override
  void dispose() {
    _entry.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final value = _entry.text.trim();
    final normalized = CatalogNormalizer.barcode(value);
    if (normalized.length < 4 || normalized.length > 64) {
      setState(() => _error = 'Use 4–64 characters.');
      return;
    }
    if (widget.barcodes.any(
      (barcode) => CatalogNormalizer.barcode(barcode.value) == normalized,
    )) {
      setState(() => _error = 'This barcode is already on the product.');
      return;
    }
    widget.onChanged([
      ...widget.barcodes,
      ProductBarcodeDraft(value: value, isPrimary: widget.barcodes.isEmpty),
    ]);
    _entry.clear();
    setState(() => _error = null);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _entry,
              focusNode: _focus,
              enabled: widget.enabled,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                labelText: 'Scan or enter barcode',
                helperText:
                    'Press Enter after scanning. Choose one primary barcode.',
                errorText: _error,
                prefixIcon: const Icon(Icons.qr_code_scanner),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Add barcode',
            onPressed: widget.enabled ? _add : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      for (var index = 0; index < widget.barcodes.length; index++)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: IconButton(
            tooltip: widget.barcodes[index].isPrimary
                ? 'Primary barcode'
                : 'Make primary',
            icon: Icon(
              widget.barcodes[index].isPrimary
                  ? Icons.star
                  : Icons.star_outline,
            ),
            onPressed: !widget.enabled
                ? null
                : () => widget.onChanged([
                    for (var i = 0; i < widget.barcodes.length; i++)
                      widget.barcodes[i].withPrimary(i == index),
                  ]),
          ),
          title: Text(widget.barcodes[index].value),
          trailing: IconButton(
            tooltip: 'Remove barcode',
            icon: const Icon(Icons.close),
            onPressed: !widget.enabled
                ? null
                : () {
                    final next = [...widget.barcodes]..removeAt(index);
                    if (next.isNotEmpty &&
                        !next.any((value) => value.isPrimary)) {
                      next[0] = next[0].withPrimary(true);
                    }
                    widget.onChanged(next);
                  },
          ),
        ),
    ],
  );
}
