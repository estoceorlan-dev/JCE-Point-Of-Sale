import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../domain/entities/catalog_category.dart';
import '../../domain/entities/catalog_drafts.dart';
import '../../domain/entities/catalog_unit.dart';
import '../controllers/product_mutation_controller.dart';
import '../providers/products_providers.dart';
import 'tax_categories_panel.dart';

class CatalogManagementDialog extends ConsumerStatefulWidget {
  const CatalogManagementDialog({super.key});

  @override
  ConsumerState<CatalogManagementDialog> createState() =>
      _CatalogManagementDialogState();
}

class _CatalogManagementDialogState
    extends ConsumerState<CatalogManagementDialog> {
  final _categoryController = TextEditingController();
  final _unitCodeController = TextEditingController();
  final _unitNameController = TextEditingController();
  final _abbreviationController = TextEditingController();
  bool _allowsFractional = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _unitCodeController.dispose();
    _unitNameController.dispose();
    _abbreviationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(allProductCategoriesProvider).value ?? const [];
    final units = ref.watch(allProductUnitsProvider).value ?? const [];
    final isSaving = ref.watch(productMutationControllerProvider).isLoading;
    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        title: const Text('Catalog settings'),
        content: SizedBox(
          width: 600,
          height: 460,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Categories'),
                  Tab(text: 'Units'),
                  Tab(text: 'Tax categories'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: TabBarView(
                  children: [
                    _categoriesTab(categories, isSaving),
                    _unitsTab(units, isSaving),
                    const TaxCategoriesPanel(),
                  ],
                ),
              ),
              if (_message != null)
                Text(
                  _message!,
                  style: TextStyle(
                    color: _isError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _categoriesTab(List<CatalogCategory> categories, bool isSaving) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: isSaving ? null : _createCategory,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: ListView(
            children: [
              for (final category in categories)
                ListTile(
                  leading: Icon(
                    category.isActive
                        ? Icons.category_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(category.name),
                  subtitle: category.isActive ? null : const Text('Archived'),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit category',
                        onPressed: isSaving
                            ? null
                            : () => _editCategory(category),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: category.isActive
                            ? 'Archive category'
                            : 'Restore category',
                        onPressed: isSaving
                            ? null
                            : () => _toggleCategory(category),
                        icon: Icon(
                          category.isActive
                              ? Icons.archive_outlined
                              : Icons.unarchive_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _unitsTab(List<CatalogUnit> units, bool isSaving) {
    return ListView(
      children: [
        TextField(
          controller: _unitCodeController,
          decoration: const InputDecoration(labelText: 'Code'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _unitNameController,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _abbreviationController,
          decoration: const InputDecoration(labelText: 'Abbreviation'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allows fractional quantities'),
          value: _allowsFractional,
          onChanged: (value) => setState(() => _allowsFractional = value),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: isSaving ? null : _createUnit,
            child: const Text('Add unit'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final unit in units)
          ListTile(
            leading: Icon(
              unit.isActive
                  ? Icons.straighten_outlined
                  : Icons.archive_outlined,
            ),
            title: Text(unit.name),
            subtitle: Text(
              '${unit.code} - ${unit.abbreviation}'
              '${unit.isActive ? '' : ' - Archived'}',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Edit unit',
                  onPressed: isSaving ? null : () => _editUnit(unit),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: unit.isActive ? 'Archive unit' : 'Restore unit',
                  onPressed: isSaving ? null : () => _toggleUnit(unit),
                  icon: Icon(
                    unit.isActive
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _createCategory() async {
    final result = await ref
        .read(productMutationControllerProvider.notifier)
        .createCategory(_categoryController.text);
    if (!mounted) {
      return;
    }
    result.fold(
      onSuccess: (_) {
        _categoryController.clear();
        _showResult('Category added.', isError: false);
      },
      onFailure: (failure) => _showResult(failure.message, isError: true),
    );
  }

  Future<void> _createUnit() async {
    final result = await ref
        .read(productMutationControllerProvider.notifier)
        .createUnit(
          UnitDraft(
            code: _unitCodeController.text,
            name: _unitNameController.text,
            abbreviation: _abbreviationController.text,
            allowsFractional: _allowsFractional,
          ),
        );
    if (!mounted) {
      return;
    }
    result.fold(
      onSuccess: (_) {
        _unitCodeController.clear();
        _unitNameController.clear();
        _abbreviationController.clear();
        _showResult('Unit added.', isError: false);
      },
      onFailure: (failure) => _showResult(failure.message, isError: true),
    );
  }

  Future<void> _editCategory(CatalogCategory category) async {
    final controller = TextEditingController(text: category.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Category name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) {
      return;
    }
    final result = await ref
        .read(productMutationControllerProvider.notifier)
        .updateCategory(categoryId: category.id, name: name);
    if (mounted) {
      _showMutationResult(result.failureOrNull?.message, 'Category updated.');
    }
  }

  Future<void> _toggleCategory(CatalogCategory category) async {
    if (category.isActive &&
        !await _confirmArchive('category', category.name)) {
      return;
    }
    final result = await ref
        .read(productMutationControllerProvider.notifier)
        .setCategoryArchived(
          categoryId: category.id,
          archived: category.isActive,
        );
    if (mounted) {
      _showMutationResult(
        result.failureOrNull?.message,
        category.isActive ? 'Category archived.' : 'Category restored.',
      );
    }
  }

  Future<void> _editUnit(CatalogUnit unit) async {
    final codeController = TextEditingController(text: unit.code);
    final nameController = TextEditingController(text: unit.name);
    final abbreviationController = TextEditingController(
      text: unit.abbreviation,
    );
    var allowsFractional = unit.allowsFractional;
    final draft = await showDialog<UnitDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit unit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: abbreviationController,
                decoration: const InputDecoration(labelText: 'Abbreviation'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allows fractional quantities'),
                value: allowsFractional,
                onChanged: (value) =>
                    setDialogState(() => allowsFractional = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                UnitDraft(
                  code: codeController.text,
                  name: nameController.text,
                  abbreviation: abbreviationController.text,
                  allowsFractional: allowsFractional,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
    nameController.dispose();
    abbreviationController.dispose();
    if (draft == null || !mounted) {
      return;
    }
    final result = await ref
        .read(productMutationControllerProvider.notifier)
        .updateUnit(unitId: unit.id, draft: draft);
    if (mounted) {
      _showMutationResult(result.failureOrNull?.message, 'Unit updated.');
    }
  }

  Future<void> _toggleUnit(CatalogUnit unit) async {
    if (unit.isActive && !await _confirmArchive('unit', unit.name)) {
      return;
    }
    final result = await ref
        .read(productMutationControllerProvider.notifier)
        .setUnitArchived(unitId: unit.id, archived: unit.isActive);
    if (mounted) {
      _showMutationResult(
        result.failureOrNull?.message,
        unit.isActive ? 'Unit archived.' : 'Unit restored.',
      );
    }
  }

  Future<bool> _confirmArchive(String type, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AppConfirmationDialog(
            title: 'Archive $type?',
            message:
                '$name will no longer be selectable for new product changes. '
                'Historical product references will remain intact.',
            confirmLabel: 'Archive',
            destructive: true,
            icon: Icons.archive_outlined,
          ),
        ) ??
        false;
  }

  void _showMutationResult(String? failure, String success) {
    _showResult(failure ?? success, isError: failure != null);
  }

  void _showResult(String message, {required bool isError}) {
    setState(() {
      _message = message;
      _isError = isError;
    });
  }
}
