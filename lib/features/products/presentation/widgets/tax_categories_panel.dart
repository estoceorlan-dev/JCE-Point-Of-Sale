import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../domain/entities/catalog_drafts.dart';
import '../../domain/entities/catalog_tax_category.dart';
import '../../domain/value_objects/minor_unit_parser.dart';
import '../providers/products_providers.dart';
import '../providers/tax_categories_providers.dart';

class TaxCategoriesPanel extends ConsumerStatefulWidget {
  const TaxCategoriesPanel({super.key});
  @override
  ConsumerState<TaxCategoriesPanel> createState() => _TaxCategoriesPanelState();
}

class _TaxCategoriesPanelState extends ConsumerState<TaxCategoriesPanel> {
  bool _saving = false;
  String? _message;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _saving ? null : () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add tax category'),
        ),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(_message!),
        ),
      const SizedBox(height: AppSpacing.sm),
      Expanded(
        child: ref
            .watch(allTaxCategoriesProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Center(
                child: Text('Tax categories could not be loaded.'),
              ),
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('No tax categories yet.'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return ListTile(
                          title: Text('${row.code} · ${row.name}'),
                          subtitle: Text(
                            '${MinorUnitParser.format(row.rateBasisPoints)}% · '
                            '${row.isInclusive ? 'Included in price' : 'Added to price'}${row.isActive ? '' : ' · Archived'}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Edit tax category',
                                onPressed: _saving || !row.isActive
                                    ? null
                                    : () => _edit(row),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: row.isActive
                                    ? 'Archive tax category'
                                    : 'Restore tax category',
                                onPressed: _saving ? null : () => _archive(row),
                                icon: Icon(
                                  row.isActive
                                      ? Icons.archive_outlined
                                      : Icons.unarchive_outlined,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      ),
    ],
  );

  Future<void> _edit([CatalogTaxCategory? category]) async {
    final draft = await showDialog<TaxCategoryDraft>(
      context: context,
      builder: (_) => TaxCategoryFormDialog(category: category),
    );
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    final result = await ref
        .read(manageTaxCategoryUseCaseProvider)
        .save(
          session: ref.read(activeProductSessionProvider),
          draft: draft,
          id: category?.id,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = result.failureOrNull?.message ?? 'Tax category saved.';
    });
  }

  Future<void> _archive(CatalogTaxCategory category) async {
    if (category.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AppConfirmationDialog(
          title: 'Archive tax category?',
          message:
              '${category.name} will no longer be available for new product changes. Historical sales keep their original tax.',
          confirmLabel: 'Archive',
          destructive: true,
          icon: Icons.archive_outlined,
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _saving = true);
    final result = await ref
        .read(manageTaxCategoryUseCaseProvider)
        .setArchived(
          session: ref.read(activeProductSessionProvider),
          id: category.id,
          archived: category.isActive,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = result.failureOrNull?.message ?? 'Tax category updated.';
    });
  }
}

class TaxCategoryFormDialog extends StatefulWidget {
  const TaxCategoryFormDialog({super.key, this.category});
  final CatalogTaxCategory? category;
  @override
  State<TaxCategoryFormDialog> createState() => _TaxCategoryFormDialogState();
}

class _TaxCategoryFormDialogState extends State<TaxCategoryFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.category?.code);
  late final _name = TextEditingController(text: widget.category?.name);
  late final _rate = TextEditingController(
    text: MinorUnitParser.format(widget.category?.rateBasisPoints ?? 0),
  );
  late bool _inclusive = widget.category?.isInclusive ?? true;
  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.category == null ? 'Add tax category' : 'Edit tax category',
    ),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Code'),
                maxLength: 32,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a code.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                maxLength: 80,
                validator: (value) =>
                    (value?.trim().length ?? 0) < 2 ? 'Enter a name.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _rate,
                decoration: const InputDecoration(labelText: 'Tax rate (%)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final rate = MinorUnitParser.tryParse(value ?? '');
                  return rate == null || rate < 0 || rate > 10000
                      ? 'Enter 0–100, with at most two decimal places.'
                      : null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Price includes tax'),
                value: _inclusive,
                onChanged: (value) => setState(() => _inclusive = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            TaxCategoryDraft(
              code: _code.text,
              name: _name.text,
              rateBasisPoints: MinorUnitParser.tryParse(_rate.text)!,
              isInclusive: _inclusive,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}
