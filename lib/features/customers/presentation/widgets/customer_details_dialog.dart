import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/customer.dart';
import '../controllers/customer_mutation_controller.dart';
import '../providers/customers_providers.dart';
import 'customer_form_dialog.dart';

class CustomerDetailsDialog extends ConsumerWidget {
  const CustomerDetailsDialog({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileProvider(customerId));
    final session = ref.watch(activeCustomerSessionProvider);
    final canManage = session?.can(AppPermission.manageCustomers) ?? false;
    final canAnonymize =
        session?.can(AppPermission.anonymizeCustomers) ?? false;
    final canManageLoyalty = session?.can(AppPermission.manageLoyalty) ?? false;
    return AlertDialog(
      title: const Text('Customer details'),
      content: SizedBox(
        width: 760,
        height: 620,
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Unable to load: $error')),
          data: (value) => value == null
              ? const Center(child: Text('Customer no longer exists.'))
              : _CustomerProfileView(
                  profile: value,
                  canManage: canManage,
                  canAnonymize: canAnonymize,
                  canManageLoyalty: canManageLoyalty,
                  onEdit: () => _edit(context, value),
                  onAddNote: () => _addNote(context, ref, value.customer),
                  onAdjust: () => _adjust(context, ref, value.customer),
                  onLifecycle: () => _lifecycle(context, ref, value.customer),
                  onMerge: () => _merge(context, ref, value.customer),
                  onAnonymize: () => _anonymize(context, ref, value.customer),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, CustomerProfile profile) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomerFormDialog(profile: profile),
    );
  }

  Future<void> _addNote(
    BuildContext context,
    WidgetRef ref,
    CustomerSummary customer,
  ) async {
    final body = await _textPrompt(
      context,
      title: 'Add customer note',
      label: 'Private operational note',
      maxLines: 4,
    );
    if (body == null) return;
    final result = await ref
        .read(customerMutationControllerProvider.notifier)
        .addNote(customer.id, body);
    if (context.mounted) _showResult(context, result, 'Note saved offline.');
  }

  Future<void> _adjust(
    BuildContext context,
    WidgetRef ref,
    CustomerSummary customer,
  ) async {
    final values = await _loyaltyPrompt(context);
    if (values == null) return;
    final result = await ref
        .read(customerMutationControllerProvider.notifier)
        .adjustLoyalty(customer.id, values.$1, values.$2);
    if (context.mounted) {
      _showResult(context, result, 'Loyalty ledger entry saved offline.');
    }
  }

  Future<void> _lifecycle(
    BuildContext context,
    WidgetRef ref,
    CustomerSummary customer,
  ) async {
    final result = customer.status == CustomerStatus.archived
        ? await ref
              .read(customerMutationControllerProvider.notifier)
              .restore(customer)
        : await ref
              .read(customerMutationControllerProvider.notifier)
              .archive(customer);
    if (context.mounted) {
      _showResult(
        context,
        result,
        customer.status == CustomerStatus.archived
            ? 'Customer restored.'
            : 'Customer archived.',
      );
    }
  }

  Future<void> _merge(
    BuildContext context,
    WidgetRef ref,
    CustomerSummary source,
  ) async {
    final customers = await ref.read(
      customerDirectoryProvider((search: '', includeInactive: false)).future,
    );
    if (!context.mounted) return;
    final targets = customers.where((value) => value.id != source.id).toList();
    final target = await showDialog<CustomerSummary>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Merge into customer'),
        children: [
          if (targets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('No other active customer is available.'),
            ),
          for (final item in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: ListTile(
                title: Text(item.displayName),
                subtitle: Text(item.customerNumber),
              ),
            ),
        ],
      ),
    );
    if (target == null) return;
    final result = await ref
        .read(customerMutationControllerProvider.notifier)
        .merge(source, target);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merged into ${target.displayName}.')),
        );
      },
      onFailure: (failure) => _showFailure(context, failure.message),
    );
  }

  Future<void> _anonymize(
    BuildContext context,
    WidgetRef ref,
    CustomerSummary customer,
  ) async {
    final reason = await _textPrompt(
      context,
      title: 'Anonymize customer',
      label: 'Legal or privacy reason',
      warning:
          'This permanently removes personal contact, address, and note data. '
          'Sales totals and audit evidence remain.',
    );
    if (reason == null) return;
    final result = await ref
        .read(customerMutationControllerProvider.notifier)
        .anonymize(customer, reason);
    if (context.mounted) _showResult(context, result, 'Customer anonymized.');
  }
}

class _CustomerProfileView extends StatelessWidget {
  const _CustomerProfileView({
    required this.profile,
    required this.canManage,
    required this.canAnonymize,
    required this.canManageLoyalty,
    required this.onEdit,
    required this.onAddNote,
    required this.onAdjust,
    required this.onLifecycle,
    required this.onMerge,
    required this.onAnonymize,
  });

  final CustomerProfile profile;
  final bool canManage;
  final bool canAnonymize;
  final bool canManageLoyalty;
  final VoidCallback onEdit;
  final VoidCallback onAddNote;
  final VoidCallback onAdjust;
  final VoidCallback onLifecycle;
  final VoidCallback onMerge;
  final VoidCallback onAnonymize;

  @override
  Widget build(BuildContext context) {
    final customer = profile.customer;
    final mutable =
        customer.status == CustomerStatus.active ||
        customer.status == CustomerStatus.archived;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              Chip(label: Text(customer.customerNumber)),
              Chip(label: Text(customer.status.label)),
              if (profile.loyaltyAccount case final account?)
                Chip(label: Text('${account.pointsBalance} loyalty points')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            customer.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            [
                  if (customer.email != null) customer.email!,
                  if (customer.phone != null) customer.phone!,
                ].isEmpty
                ? 'No contact details'
                : [
                    if (customer.email != null) customer.email!,
                    if (customer.phone != null) customer.phone!,
                  ].join(' • '),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (canManage && mutable)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              if (canManage && mutable)
                OutlinedButton.icon(
                  onPressed: onAddNote,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Add note'),
                ),
              if (canManage && mutable)
                OutlinedButton.icon(
                  onPressed: onLifecycle,
                  icon: Icon(
                    customer.status == CustomerStatus.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label: Text(
                    customer.status == CustomerStatus.archived
                        ? 'Restore'
                        : 'Archive',
                  ),
                ),
              if (canManage && customer.status == CustomerStatus.active)
                OutlinedButton.icon(
                  onPressed: onMerge,
                  icon: const Icon(Icons.merge_outlined),
                  label: const Text('Merge'),
                ),
              if (canManageLoyalty && customer.status == CustomerStatus.active)
                OutlinedButton.icon(
                  onPressed: onAdjust,
                  icon: const Icon(Icons.stars_outlined),
                  label: const Text('Adjust points'),
                ),
              if (canAnonymize && mutable)
                TextButton.icon(
                  onPressed: onAnonymize,
                  icon: const Icon(Icons.no_accounts_outlined),
                  label: const Text('Anonymize'),
                ),
            ],
          ),
          const Divider(height: AppSpacing.xxl),
          _Section(
            title: 'Addresses',
            empty: 'No saved address.',
            children: [
              for (final address in profile.addresses)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(address.label),
                  subtitle: Text(address.formatted),
                ),
            ],
          ),
          _Section(
            title: 'Branch purchase history',
            empty: 'No purchases attributed to this customer in this branch.',
            children: [
              for (final purchase in profile.purchases)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(purchase.receiptNumber),
                  subtitle: Text(
                    '${purchase.status} • ${purchase.completedAt.toLocal()}',
                  ),
                  trailing: Text(Formatters.currencyMinor(purchase.totalMinor)),
                ),
            ],
          ),
          _Section(
            title: 'Private branch notes',
            empty: 'No notes for this branch.',
            children: [
              for (final note in profile.notes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: Text(note.body),
                  subtitle: Text(note.createdAt.toLocal().toString()),
                ),
            ],
          ),
          if (profile.loyaltyAccount case final account?)
            _Section(
              title: 'Immutable loyalty ledger',
              empty: 'No loyalty activity.',
              children: [
                for (final entry in account.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      entry.pointsDelta > 0
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                    ),
                    title: Text(entry.reason),
                    subtitle: Text(
                      '${entry.type.label} • balance ${entry.balanceAfter} • '
                      '${entry.occurredAt.toLocal()}',
                    ),
                    trailing: Text(
                      '${entry.pointsDelta > 0 ? '+' : ''}${entry.pointsDelta}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(empty),
          )
        else
          ...children,
      ],
    ),
  );
}

Future<String?> _textPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String? warning,
  int maxLines = 2,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (warning != null) ...[
              Text(warning),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: maxLines,
              decoration: InputDecoration(labelText: label),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<(int, String)?> _loyaltyPrompt(BuildContext context) async {
  final points = TextEditingController();
  final reason = TextEditingController();
  final result = await showDialog<(int, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Adjust loyalty points'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: points,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Points (negative to deduct)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(points.text.trim());
            if (value != null) Navigator.pop(context, (value, reason.text));
          },
          child: const Text('Post entry'),
        ),
      ],
    ),
  );
  points.dispose();
  reason.dispose();
  return result;
}

void _showResult(
  BuildContext context,
  Result<void, Failure> result,
  String successMessage,
) {
  result.fold(
    onSuccess: (_) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage))),
    onFailure: (failure) => _showFailure(context, failure.message),
  );
}

void _showFailure(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
