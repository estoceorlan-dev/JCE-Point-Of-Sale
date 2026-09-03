import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../products/domain/entities/product_query.dart';
import '../../../products/domain/entities/product_summary.dart';
import '../../../products/presentation/providers/products_providers.dart';
import '../../../settings/domain/entities/reason_code.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/inventory_adjustment.dart';
import '../../domain/entities/inventory_balance.dart';
import '../../domain/entities/stock_location.dart';
import '../controllers/inventory_mutation_controller.dart';
import '../providers/inventory_providers.dart';

class InventoryAdjustmentDialog extends ConsumerStatefulWidget {
  const InventoryAdjustmentDialog({super.key});

  @override
  ConsumerState<InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends ConsumerState<InventoryAdjustmentDialog> {
  static const _productQuery = ProductQuery(pageSize: 250);

  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  String? _locationId;
  String? _productId;
  String? _reasonCode;
  bool _increase = true;
  bool _approveAsManager = false;
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(stockLocationsProvider).value ?? const [];
    final products =
        ref.watch(productPageProvider(_productQuery)).value?.items ?? const [];
    final balances =
        ref
            .watch(inventoryBalancesProvider(const InventoryBalanceQuery()))
            .value ??
        const [];
    final policy = ref.watch(inventoryPolicyProvider).value;
    final configuredReasons =
        ref
            .watch(reasonCodesProvider)
            .valueOrNull
            ?.where(
              (reason) =>
                  reason.isActive &&
                  reason.category == ReasonCodeCategory.inventoryAdjustment,
            )
            .toList(growable: false) ??
        const <ReasonCode>[];
    final selectedReason = configuredReasons
        .where((reason) => reason.code == _reasonCode)
        .firstOrNull;
    final session = ref.watch(activeInventorySessionProvider);
    final canApprove =
        session?.can(AppPermission.approveInventoryAdjustments) ?? false;
    final saving = ref.watch(inventoryMutationControllerProvider).isLoading;
    final selectedBalance = _selectedBalance(balances);
    return AlertDialog(
      title: const Text('Inventory adjustment'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _locationId,
                  decoration: const InputDecoration(
                    labelText: 'Stock location',
                  ),
                  items: _locationItems(locations),
                  onChanged: saving
                      ? null
                      : (value) => setState(() => _locationId = value),
                  validator: (value) =>
                      value == null ? 'Select a location.' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: _productItems(products),
                  onChanged: saving
                      ? null
                      : (value) => setState(() => _productId = value),
                  validator: (value) =>
                      value == null ? 'Select a product.' : null,
                ),
                if (selectedBalance != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Current on hand: ${Formatters.quantityMilli(selectedBalance.onHandMilli)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.add),
                      label: Text('Increase'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.remove),
                      label: Text('Decrease'),
                    ),
                  ],
                  selected: {_increase},
                  onSelectionChanged: saving
                      ? null
                      : (value) => setState(() => _increase = value.single),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    helperText: 'Up to three decimal places',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final quantity = Formatters.parseQuantityMilli(value ?? '');
                    return quantity == null || quantity <= 0
                        ? 'Enter a quantity greater than zero.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                if (configuredReasons.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _reasonCode,
                    decoration: const InputDecoration(
                      labelText: 'Adjustment reason',
                    ),
                    items: [
                      for (final reason in configuredReasons)
                        DropdownMenuItem(
                          value: reason.code,
                          child: Text(reason.label),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => setState(() => _reasonCode = value),
                    validator: (value) =>
                        value == null ? 'Select an adjustment reason.' : null,
                  ),
                if (configuredReasons.isEmpty)
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Adjustment reason',
                      hintText: 'Damage, recount, receiving correction…',
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter the reason for this adjustment.'
                        : null,
                  ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                  validator: (value) =>
                      selectedReason?.requiresNote == true &&
                          (value?.trim().isEmpty ?? true)
                      ? 'This reason requires an explanatory note.'
                      : null,
                ),
                if (policy?.adjustmentApprovalThresholdMilli
                    case final threshold?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      'Manager approval is required above ${Formatters.quantityMilli(threshold)} units.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (canApprove)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Approve this adjustment as manager'),
                    value: _approveAsManager,
                    onChanged: saving
                        ? null
                        : (value) => setState(
                            () => _approveAsManager = value ?? false,
                          ),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Posting…' : 'Post adjustment'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _locationItems(List<StockLocation> locations) {
    return [
      for (final location in locations.where((item) => item.isActive))
        DropdownMenuItem(value: location.id, child: Text(location.name)),
    ];
  }

  List<DropdownMenuItem<String>> _productItems(List<ProductSummary> products) {
    return [
      for (final product in products)
        DropdownMenuItem(
          value: product.id,
          child: Text('${product.sku} — ${product.name}'),
        ),
    ];
  }

  InventoryBalance? _selectedBalance(List<InventoryBalance> balances) {
    for (final balance in balances) {
      if (balance.stockLocationId == _locationId &&
          balance.productId == _productId) {
        return balance;
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final magnitude = Formatters.parseQuantityMilli(_quantityController.text)!;
    final balances = await ref.read(
      inventoryBalancesProvider(const InventoryBalanceQuery()).future,
    );
    final balance = _selectedBalance(balances);
    setState(() => _error = null);
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .createAdjustment(
          InventoryAdjustmentDraft(
            stockLocationId: _locationId!,
            productId: _productId!,
            quantityDeltaMilli: _increase ? magnitude : -magnitude,
            reasonCode: _reasonCode ?? _reasonController.text,
            notes: _notesController.text,
            expectedBalanceVersion: balance?.version ?? 0,
          ),
          approveAsManager: _approveAsManager,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
