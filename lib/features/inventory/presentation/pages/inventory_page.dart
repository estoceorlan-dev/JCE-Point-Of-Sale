import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../providers/inventory_providers.dart';
import '../widgets/inventory_adjustment_dialog.dart';
import '../widgets/inventory_balance_panel.dart';
import '../widgets/inventory_movement_panel.dart';
import '../widgets/inventory_policy_dialog.dart';
import '../widgets/start_stock_count_dialog.dart';
import '../widgets/stock_count_panel.dart';
import '../widgets/stock_location_dialog.dart';
import '../../../imports/domain/entities/csv_import.dart';
import '../../../imports/presentation/widgets/csv_import_dialog.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeInventorySessionProvider);
    final locations = ref.watch(stockLocationsProvider).value ?? const [];
    final canManageSettings =
        session?.can(AppPermission.manageSettings) ?? false;
    return DefaultTabController(
      length: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < AppBreakpoints.compact
              ? AppSpacing.lg
              : AppSpacing.xxl;
          return Padding(
            padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.contentMaxWidth,
                  ),
                  child: _InventoryHeader(
                    hasLocations: locations.isNotEmpty,
                    canManageSettings: canManageSettings,
                    onCreateLocation: () => _openLocation(context),
                    onAdjust: () => _openAdjustment(context),
                    onStartCount: () => _openCount(context),
                    onConfigurePolicy: () => _openPolicy(context, ref),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextButton.icon(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const CsvImportDialog(kind: CsvImportKind.openingStock),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import opening stock'),
                ),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined),
                      text: 'Balances',
                    ),
                    Tab(icon: Icon(Icons.history), text: 'Movement history'),
                    Tab(
                      icon: Icon(Icons.fact_check_outlined),
                      text: 'Stock counts',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Expanded(
                  child: TabBarView(
                    children: [
                      _ScrollablePanel(child: InventoryBalancePanel()),
                      _ScrollablePanel(child: InventoryMovementPanel()),
                      _ScrollablePanel(child: StockCountPanel()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openLocation(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const StockLocationDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock location created.')));
    }
  }

  Future<void> _openAdjustment(BuildContext context) async {
    final posted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const InventoryAdjustmentDialog(),
    );
    if (posted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory adjustment posted.')),
      );
    }
  }

  Future<void> _openCount(BuildContext context) async {
    final started = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const StartStockCountDialog(),
    );
    if (started == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock count started; the location is now frozen.'),
        ),
      );
    }
  }

  Future<void> _openPolicy(BuildContext context, WidgetRef ref) async {
    final policy = await ref.read(inventoryPolicyProvider.future);
    if (!context.mounted || policy == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InventoryPolicyDialog(policy: policy),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch inventory policy updated.')),
      );
    }
  }
}

class _ScrollablePanel extends StatelessWidget {
  const _ScrollablePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
        child: child,
      ),
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader({
    required this.hasLocations,
    required this.canManageSettings,
    required this.onCreateLocation,
    required this.onAdjust,
    required this.onStartCount,
    required this.onConfigurePolicy,
  });

  final bool hasLocations;
  final bool canManageSettings;
  final VoidCallback onCreateLocation;
  final VoidCallback onAdjust;
  final VoidCallback onStartCount;
  final VoidCallback onConfigurePolicy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Branch stock balances derived from an immutable offline ledger.',
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onCreateLocation,
          icon: const Icon(Icons.warehouse_outlined),
          label: const Text('New location'),
        ),
        if (canManageSettings)
          OutlinedButton.icon(
            onPressed: onConfigurePolicy,
            icon: const Icon(Icons.policy_outlined),
            label: const Text('Policy'),
          ),
        OutlinedButton.icon(
          onPressed: hasLocations ? onStartCount : null,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Start count'),
        ),
        FilledButton.icon(
          onPressed: hasLocations ? onAdjust : null,
          icon: const Icon(Icons.tune),
          label: const Text('Adjust stock'),
        ),
      ],
    );
  }
}
