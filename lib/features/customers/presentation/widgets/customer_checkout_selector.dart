import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/customer.dart';
import '../providers/customers_providers.dart';

class CustomerCheckoutSelector extends ConsumerWidget {
  const CustomerCheckoutSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCheckoutCustomerProvider);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(selected?.displayName ?? 'Walk-in customer'),
        subtitle: Text(
          selected == null
              ? 'Customer attribution is optional.'
              : [
                  selected.customerNumber,
                  if (selected.phone != null) selected.phone!,
                  if (selected.loyaltyPoints case final points?)
                    '$points loyalty points',
                ].join(' • '),
        ),
        trailing: Wrap(
          spacing: AppSpacing.xs,
          children: [
            if (selected != null)
              IconButton(
                tooltip: 'Remove customer',
                onPressed: () =>
                    ref.read(selectedCheckoutCustomerProvider.notifier).state =
                        null,
                icon: const Icon(Icons.close),
              ),
            TextButton.icon(
              key: const Key('choose-checkout-customer'),
              onPressed: () => _choose(context, ref),
              icon: const Icon(Icons.search),
              label: Text(selected == null ? 'Choose customer' : 'Change'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final customer = await showDialog<CustomerSummary>(
      context: context,
      builder: (context) => const _CustomerLookupDialog(),
    );
    if (customer != null) {
      ref.read(selectedCheckoutCustomerProvider.notifier).state = customer;
    }
  }
}

class _CustomerLookupDialog extends ConsumerStatefulWidget {
  const _CustomerLookupDialog();

  @override
  ConsumerState<_CustomerLookupDialog> createState() =>
      _CustomerLookupDialogState();
}

class _CustomerLookupDialogState extends ConsumerState<_CustomerLookupDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(
      customerDirectoryProvider((search: _search, includeInactive: false)),
    );
    return AlertDialog(
      title: const Text('Choose customer'),
      content: SizedBox(
        width: 560,
        height: 440,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Name, email, phone, or customer number',
              ),
              onChanged: _onSearch,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: customers.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Customer lookup failed: $error')),
                data: (items) => items.isEmpty
                    ? const Center(child: Text('No matching customers.'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final customer = items[index];
                          return ListTile(
                            title: Text(customer.displayName),
                            subtitle: Text(
                              [
                                customer.customerNumber,
                                if (customer.email != null) customer.email!,
                                if (customer.phone != null) customer.phone!,
                              ].join(' • '),
                            ),
                            trailing: customer.loyaltyPoints == null
                                ? null
                                : Chip(
                                    label: Text(
                                      '${customer.loyaltyPoints} points',
                                    ),
                                  ),
                            onTap: () => Navigator.pop(context, customer),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }
}
