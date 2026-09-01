import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../domain/entities/customer.dart';
import '../providers/customers_providers.dart';
import '../widgets/customer_details_dialog.dart';
import '../widgets/customer_form_dialog.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  bool _includeInactive = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeCustomerSessionProvider);
    final canManage = session?.can(AppPermission.manageCustomers) ?? false;
    final customers = ref.watch(
      customerDirectoryProvider((
        search: _search,
        includeInactive: _includeInactive,
      )),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < AppBreakpoints.compact
            ? AppSpacing.lg
            : AppSpacing.xxl;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
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
                        width: 620,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customers & loyalty',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Offline customer lookup, purchase attribution, '
                              'privacy workflows, and immutable loyalty history.',
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        key: const Key('new-customer-button'),
                        onPressed: canManage ? () => _create(context) : null,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('New customer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 520,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText:
                                'Search name, email, phone, or customer number',
                          ),
                          onChanged: _onSearch,
                        ),
                      ),
                      FilterChip(
                        selected: _includeInactive,
                        onSelected: (value) =>
                            setState(() => _includeInactive = value),
                        label: const Text('Include inactive'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  customers.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text('Customers could not be loaded: $error'),
                      ),
                    ),
                    data: (items) => _CustomerTable(
                      customers: items,
                      onOpen: (customer) => _open(context, customer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  Future<void> _create(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CustomerFormDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Customer saved offline.')));
    }
  }

  Future<void> _open(BuildContext context, CustomerSummary customer) =>
      showDialog<void>(
        context: context,
        builder: (context) => CustomerDetailsDialog(customerId: customer.id),
      );
}

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({required this.customers, required this.onOpen});

  final List<CustomerSummary> customers;
  final ValueChanged<CustomerSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: Text('No matching customers.')),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Contact')),
            DataColumn(label: Text('Status')),
            DataColumn(numeric: true, label: Text('Loyalty')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final customer in customers)
              DataRow(
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.displayName),
                        Text(
                          customer.customerNumber,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      [
                        if (customer.email != null) customer.email!,
                        if (customer.phone != null) customer.phone!,
                      ].join(' • '),
                    ),
                  ),
                  DataCell(Chip(label: Text(customer.status.label))),
                  DataCell(Text(customer.loyaltyPoints?.toString() ?? '—')),
                  DataCell(
                    IconButton(
                      tooltip: 'Open customer',
                      onPressed: () => onOpen(customer),
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
