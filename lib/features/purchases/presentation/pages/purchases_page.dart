import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';
import '../controllers/purchase_mutation_controller.dart';
import '../providers/purchases_providers.dart';
import '../widgets/create_purchase_order_dialog.dart';
import '../widgets/create_supplier_dialog.dart';
import '../widgets/purchase_order_details_dialog.dart';

enum _PurchaseView { orders, suppliers }

class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  _PurchaseView _view = _PurchaseView.orders;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activePurchaseSessionProvider);
    final canCreate = session?.can(AppPermission.createPurchases) ?? false;
    final canManageSuppliers =
        session?.can(AppPermission.manageSuppliers) ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < AppBreakpoints.compact
            ? AppSpacing.lg
            : AppSpacing.xxl;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 560,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchasing & receiving',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Supplier records, approval-ready purchase orders, partial receipts, and weighted-average costs — fully offline.',
                          ),
                        ],
                      ),
                    ),
                    if (_view == _PurchaseView.suppliers)
                      FilledButton.icon(
                        onPressed: canManageSuppliers
                            ? () => _createSupplier(context)
                            : null,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('New supplier'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: canCreate
                            ? () => _createOrder(context)
                            : null,
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        label: const Text('New purchase order'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SegmentedButton<_PurchaseView>(
                  segments: const [
                    ButtonSegment(
                      value: _PurchaseView.orders,
                      icon: Icon(Icons.description_outlined),
                      label: Text('Purchase orders'),
                    ),
                    ButtonSegment(
                      value: _PurchaseView.suppliers,
                      icon: Icon(Icons.local_shipping_outlined),
                      label: Text('Suppliers'),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (value) =>
                      setState(() => _view = value.single),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_view == _PurchaseView.orders)
                  ref
                      .watch(purchaseOrdersProvider)
                      .when(
                        loading: _loading,
                        error: _error,
                        data: (orders) => _PurchaseOrderList(
                          orders: orders,
                          onOpen: (order) => _openOrder(context, order),
                        ),
                      )
                else
                  ref
                      .watch(suppliersProvider)
                      .when(
                        loading: _loading,
                        error: _error,
                        data: (suppliers) => _SupplierList(
                          suppliers: suppliers,
                          canArchive: canManageSuppliers,
                          onArchive: (supplier) => _archiveSupplier(supplier),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _loading() => const Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.xxl),
      child: CircularProgressIndicator(),
    ),
  );

  Widget _error(Object error, StackTrace _) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text('Purchasing data could not be loaded: $error'),
    ),
  );

  Future<void> _createSupplier(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateSupplierDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Supplier saved offline.')));
    }
  }

  Future<void> _createOrder(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreatePurchaseOrderDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase order draft saved offline.')),
      );
    }
  }

  Future<void> _openOrder(BuildContext context, PurchaseOrder order) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PurchaseOrderDetailsDialog(order: order),
    );
  }

  Future<void> _archiveSupplier(Supplier supplier) async {
    final result = await ref
        .read(purchaseMutationControllerProvider.notifier)
        .archiveSupplier(supplier);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Supplier archived.'))),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _PurchaseOrderList extends StatelessWidget {
  const _PurchaseOrderList({required this.orders, required this.onOpen});

  final List<PurchaseOrder> orders;
  final ValueChanged<PurchaseOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: Text('No purchase orders for this branch yet.')),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Purchase order')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Status')),
            DataColumn(numeric: true, label: Text('Ordered')),
            DataColumn(numeric: true, label: Text('Received')),
            DataColumn(numeric: true, label: Text('Remaining')),
            DataColumn(numeric: true, label: Text('Value')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final order in orders)
              DataRow(
                cells: [
                  DataCell(Text(order.orderNumber)),
                  DataCell(Text(order.supplierName)),
                  DataCell(Chip(label: Text(order.status.label))),
                  DataCell(
                    Text(
                      Formatters.quantityMilli(order.totalOrderedQuantityMilli),
                    ),
                  ),
                  DataCell(
                    Text(
                      Formatters.quantityMilli(
                        order.totalReceivedQuantityMilli,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      Formatters.quantityMilli(
                        order.totalRemainingQuantityMilli,
                      ),
                    ),
                  ),
                  DataCell(Text(Formatters.currencyMinor(order.totalMinor))),
                  DataCell(
                    IconButton(
                      tooltip: 'Open purchase order',
                      onPressed: () => onOpen(order),
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SupplierList extends StatelessWidget {
  const _SupplierList({
    required this.suppliers,
    required this.canArchive,
    required this.onArchive,
  });

  final List<Supplier> suppliers;
  final bool canArchive;
  final ValueChanged<Supplier> onArchive;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: Text('No suppliers have been added yet.')),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Primary contact')),
            DataColumn(numeric: true, label: Text('Terms')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final supplier in suppliers)
              DataRow(
                cells: [
                  DataCell(Text(supplier.code)),
                  DataCell(Text(supplier.name)),
                  DataCell(Text(_primaryContact(supplier))),
                  DataCell(Text('${supplier.paymentTermsDays} days')),
                  DataCell(Text(supplier.isActive ? 'Active' : 'Archived')),
                  DataCell(
                    IconButton(
                      tooltip: 'Archive supplier',
                      onPressed: canArchive && supplier.isActive
                          ? () => onArchive(supplier)
                          : null,
                      icon: const Icon(Icons.archive_outlined),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _primaryContact(Supplier supplier) {
    if (supplier.contacts.isEmpty) return '—';
    final primary = supplier.contacts.firstWhere(
      (contact) => contact.isPrimary,
      orElse: () => supplier.contacts.first,
    );
    return '${primary.name}${primary.email == null ? '' : ' • ${primary.email}'}';
  }
}
