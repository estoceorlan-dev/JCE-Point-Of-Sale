import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/payment.dart';
import '../../domain/value_objects/cart_pricing.dart';
import '../controllers/checkout_controller.dart';
import 'external_payment_confirmation.dart';

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
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();
  final _cardReferenceController = TextEditingController();
  final _walletController = TextEditingController();
  final _walletReferenceController = TextEditingController();
  bool _approved = false;
  bool _cardConfirmed = false;
  bool _walletConfirmed = false;
  bool _submitting = false;
  bool _externalPaymentSaveFailed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(_amountChanged);
    _cardController.addListener(_cardChanged);
    _cardReferenceController.addListener(_cardChanged);
    _walletController.addListener(_walletChanged);
    _walletReferenceController.addListener(_walletChanged);
  }

  @override
  void dispose() {
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
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
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
                const Text(
                  'Manual payment recording. Receive cash before entering it. '
                  'For card or QR, key the amount into your separate terminal or '
                  'payment app and verify approval there. This POS does not send '
                  'charges or verify payment with a provider.',
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ActionChip(
                      label: const Text('Exact cash'),
                      onPressed: _submitting
                          ? null
                          : () => _cashController.text = _cashBalance > 0
                                ? (_cashBalance / 100).toStringAsFixed(2)
                                : '',
                    ),
                    for (final amount in _cashPresets(
                      widget.pricing.totalMinor,
                    ))
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
                  label: 'Cash received',
                  controller: _cashController,
                  enabled: !_submitting,
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                _PaymentField(
                  key: const Key('card-payment-field'),
                  label: 'Card amount',
                  controller: _cardController,
                  referenceController: _cardReferenceController,
                  enabled: !_submitting,
                  requireReference: widget.requireNonCashReference,
                  icon: Icons.credit_card_outlined,
                ),
                if (_positiveAmount(_cardController) case final amount
                    when amount > 0)
                  ExternalPaymentConfirmation(
                    key: const Key('card-payment-confirmation'),
                    methodLabel: 'Card',
                    amountMinor: amount,
                    confirmed: _cardConfirmed,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _cardConfirmed = value),
                  ),
                const SizedBox(height: AppSpacing.md),
                _PaymentField(
                  key: const Key('wallet-payment-field'),
                  label: 'QR / E-wallet amount',
                  controller: _walletController,
                  referenceController: _walletReferenceController,
                  enabled: !_submitting,
                  requireReference: widget.requireNonCashReference,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                if (_positiveAmount(_walletController) case final amount
                    when amount > 0)
                  ExternalPaymentConfirmation(
                    key: const Key('wallet-payment-confirmation'),
                    methodLabel: 'QR / E-wallet',
                    amountMinor: amount,
                    confirmed: _walletConfirmed,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _walletConfirmed = value),
                  ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Complete sale saves the payment and prepares the receipt. '
                  'A configured printer prints afterward; otherwise use the '
                  'screen receipt or Save PDF. Handle cash and change manually.',
                ),
                if (widget.requiresDiscountApproval) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (widget.canApproveDiscount)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _approved,
                      onChanged: _submitting
                          ? null
                          : (value) =>
                                setState(() => _approved = value ?? false),
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
                if (_externalPaymentSaveFailed) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'The sale was not saved. Do not charge the customer again. '
                    'Keep the approved payment reference and reconcile it with '
                    'a supervisor before retrying the local save or leaving this cart.',
                    key: Key('external-payment-save-failure'),
                  ),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
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
      if ((input.method == SalePaymentMethod.card && !_cardConfirmed) ||
          (input.method == SalePaymentMethod.eWallet && !_walletConfirmed)) {
        setState(
          () => _error =
              'Verify the ${input.method.label} payment was approved '
              'on the terminal or payment app, then confirm it here.',
        );
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
        _externalPaymentSaveFailed =
            _externalPaymentSaveFailed ||
            tenders.any((tender) => tender.method != SalePaymentMethod.cash);
        _error = failure.message;
      }),
    );
  }

  void _amountChanged() {
    if (mounted) setState(() => _error = null);
  }

  void _cardChanged() {
    _cardConfirmed = false;
    _amountChanged();
  }

  void _walletChanged() {
    _walletConfirmed = false;
    _amountChanged();
  }

  int _positiveAmount(TextEditingController controller) {
    final amount = Formatters.parseCurrencyMinor(controller.text) ?? 0;
    return amount > 0 ? amount : 0;
  }

  int get _cashBalance =>
      widget.pricing.totalMinor -
      _positiveAmount(_cardController) -
      _positiveAmount(_walletController);
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
    required this.enabled,
    this.requireReference = false,
    this.referenceController,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final TextEditingController? referenceController;
  final IconData icon;
  final bool enabled;
  final bool requireReference;

  @override
  Widget build(BuildContext context) {
    final amount = TextField(
      enabled: enabled,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'PHP ',
        prefixIcon: Icon(icon),
      ),
    );
    if (referenceController == null) return amount;
    final reference = TextField(
      enabled: enabled,
      controller: referenceController,
      decoration: InputDecoration(
        labelText: requireReference
            ? 'Reference (required)'
            : 'Reference (optional)',
        helperText: 'Transaction reference only; no card number or PIN.',
        helperMaxLines: 3,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 440
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                amount,
                const SizedBox(height: AppSpacing.sm),
                reference,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: amount),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: reference),
              ],
            ),
    );
  }
}
