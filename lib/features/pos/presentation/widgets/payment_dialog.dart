import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/payment.dart';
import '../../domain/value_objects/cart_pricing.dart';
import '../controllers/checkout_controller.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({
    required this.pricing,
    required this.requiresDiscountApproval,
    required this.canApproveDiscount,
    required this.requireNonCashReference,
    super.key,
  });

  final CartPricing pricing;
  final bool requiresDiscountApproval;
  final bool canApproveDiscount;
  final bool requireNonCashReference;

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  late final _cashController = TextEditingController(
    text: (widget.pricing.totalMinor / 100).toStringAsFixed(2),
  );
  final _cardController = TextEditingController();
  final _cardReferenceController = TextEditingController();
  final _walletController = TextEditingController();
  final _walletReferenceController = TextEditingController();
  bool _approved = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _cashController,
      _cardController,
      _walletController,
    ]) {
      controller.addListener(_amountChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _cashController,
      _cardController,
      _walletController,
    ]) {
      controller.removeListener(_amountChanged);
    }
    _cashController.dispose();
    _cardController.dispose();
    _cardReferenceController.dispose();
    _walletController.dispose();
    _walletReferenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entered = [_cashController, _cardController, _walletController]
        .map(
          (controller) => Formatters.parseCurrencyMinor(controller.text) ?? 0,
        )
        .fold<int>(0, (total, amount) => total + amount);
    final remaining = widget.pricing.totalMinor - entered;
    return AlertDialog(
      title: const Text('Take payment'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.currencyMinor(widget.pricing.totalMinor),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                remaining > 0
                    ? 'Remaining ${Formatters.currencyMinor(remaining)}'
                    : remaining == 0
                    ? 'Fully tendered'
                    : 'Change / excess ${Formatters.currencyMinor(-remaining)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: remaining > 0
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ActionChip(
                    label: const Text('Exact cash'),
                    onPressed: _submitting
                        ? null
                        : () => _cashController.text =
                              (widget.pricing.totalMinor / 100).toStringAsFixed(
                                2,
                              ),
                  ),
                  for (final amount in _cashPresets(widget.pricing.totalMinor))
                    ActionChip(
                      label: Text(Formatters.currencyMinor(amount)),
                      onPressed: _submitting
                          ? null
                          : () => _cashController.text = (amount / 100)
                                .toStringAsFixed(2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _PaymentField(
                key: const Key('cash-payment-field'),
                label: 'Cash tendered',
                controller: _cashController,
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              _PaymentField(
                key: const Key('card-payment-field'),
                label: 'Card amount',
                controller: _cardController,
                referenceController: _cardReferenceController,
                icon: Icons.credit_card_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              _PaymentField(
                key: const Key('wallet-payment-field'),
                label: 'E-wallet amount',
                controller: _walletController,
                referenceController: _walletReferenceController,
                icon: Icons.account_balance_wallet_outlined,
              ),
              if (widget.requiresDiscountApproval) ...[
                const SizedBox(height: AppSpacing.md),
                if (widget.canApproveDiscount)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _approved,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _approved = value ?? false),
                    title: const Text('Approve this discount as manager'),
                    subtitle: const Text(
                      'The approval identity and time will be stored with the sale.',
                    ),
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'This discount exceeds the branch threshold. A user with discount approval permission must complete it.',
                      ),
                    ),
                  ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('complete-sale-button'),
          onPressed:
              _submitting ||
                  (widget.requiresDiscountApproval &&
                      (!widget.canApproveDiscount || !_approved))
              ? null
              : _submit,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('Complete sale'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final tenders = <PaymentTender>[];
    final inputs = [
      (
        method: SalePaymentMethod.cash,
        controller: _cashController,
        reference: null as TextEditingController?,
      ),
      (
        method: SalePaymentMethod.card,
        controller: _cardController,
        reference: _cardReferenceController,
      ),
      (
        method: SalePaymentMethod.eWallet,
        controller: _walletController,
        reference: _walletReferenceController,
      ),
    ];
    for (final input in inputs) {
      if (input.controller.text.trim().isEmpty) continue;
      final amount = Formatters.parseCurrencyMinor(input.controller.text);
      if (amount == null || amount <= 0) {
        setState(() => _error = 'Enter valid positive payment amounts.');
        return;
      }
      if (widget.requireNonCashReference &&
          input.method != SalePaymentMethod.cash &&
          (input.reference?.text.trim().isEmpty ?? true)) {
        setState(() => _error = '${input.method.label} reference is required.');
        return;
      }
      tenders.add(
        PaymentTender(
          method: input.method,
          tenderedAmountMinor: amount,
          reference: input.reference?.text.trim().isEmpty ?? true
              ? null
              : input.reference!.text.trim(),
        ),
      );
    }
    try {
      PaymentCalculator.reconcile(
        totalMinor: widget.pricing.totalMinor,
        tenders: tenders,
      );
    } on Failure catch (failure) {
      setState(() => _error = failure.message);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(checkoutControllerProvider.notifier)
        .checkout(tenders: tenders, approveDiscountAsManager: _approved);
    if (!mounted) return;
    result.fold(
      onSuccess: (checkout) => Navigator.pop(context, checkout),
      onFailure: (failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
    );
  }

  void _amountChanged() {
    if (mounted) setState(() {});
  }
}

List<int> _cashPresets(int totalMinor) {
  final candidates = <int>{
    ((totalMinor + 999) ~/ 1000) * 1000,
    ((totalMinor + 4999) ~/ 5000) * 5000,
    50000,
    100000,
  }..removeWhere((value) => value <= totalMinor);
  return candidates.toList()..sort();
}

class _PaymentField extends StatelessWidget {
  const _PaymentField({
    required this.label,
    required this.controller,
    required this.icon,
    this.referenceController,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final TextEditingController? referenceController;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              prefixText: 'PHP ',
              prefixIcon: Icon(icon),
            ),
          ),
        ),
        if (referenceController case final reference?) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
