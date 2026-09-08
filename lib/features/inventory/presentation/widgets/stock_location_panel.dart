import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../domain/entities/stock_location.dart';
import '../controllers/inventory_mutation_controller.dart';
import '../providers/inventory_providers.dart';
import 'stock_location_dialog.dart';

class StockLocationPanel extends ConsumerStatefulWidget {
  const StockLocationPanel({super.key});
  @override
  ConsumerState<StockLocationPanel> createState() => _StockLocationPanelState();
}

class _StockLocationPanelState extends ConsumerState<StockLocationPanel> {
  bool _includeArchived = false;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(stockLocationDirectoryProvider(_includeArchived));
    final busy = ref.watch(inventoryMutationControllerProvider).isLoading;
    final allowed =
        ref
            .watch(activeInventorySessionProvider)
            ?.can(AppPermission.manageInventory) ??
        false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: const Text('Show archived locations'),
              selected: _includeArchived,
              onSelected: (value) => setState(() => _includeArchived = value),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Archiving keeps movement history. Move remaining stock, finish counts and transfers, then synchronize pending operations first.',
        ),
        const SizedBox(height: AppSpacing.md),
        rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Stock locations could not be loaded.'),
          data: (locations) => locations.isEmpty
              ? const Text('No stock locations match this view.')
              : Column(
                  children: [
                    for (final location in locations)
                      Card(
                        child: ListTile(
                          title: Text(location.name),
                          subtitle: Text(
                            '${location.code} · ${location.type.label}\n${location.isActive ? (location.isDefault ? 'Active · Default' : 'Active') : 'Archived'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            enabled: allowed && !busy,
                            tooltip: 'Location actions',
                            onSelected: (action) => action == 'edit'
                                ? _edit(location)
                                : _archive(location, action == 'archive'),
                            itemBuilder: (_) => [
                              if (location.isActive)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit location'),
                                ),
                              PopupMenuItem(
                                value: location.isActive
                                    ? 'archive'
                                    : 'restore',
                                child: Text(
                                  location.isActive
                                      ? 'Archive location'
                                      : 'Restore location',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _edit(StockLocation location) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockLocationDialog(location: location),
    );
  }

  Future<void> _archive(StockLocation location, bool archived) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(archived ? 'Archive location?' : 'Restore location?'),
        content: Text(
          archived
              ? '${location.name} will be unavailable for new operations. Its stock history will remain accessible.'
              : '${location.name} will become available for new operations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(archived ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(inventoryMutationControllerProvider.notifier)
        .setLocationArchived(location, archived);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Saved locally and queued for sync.'
              : result.failureOrNull!.message,
        ),
      ),
    );
  }
}
