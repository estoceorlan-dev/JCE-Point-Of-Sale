import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_text_input_formatter.dart';
import '../../../../core/widgets/app_number_pad.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/checkout_attempt.dart';
import '../../domain/value_objects/cart_pricing.dart';
import '../controllers/checkout_controller.dart';
import 'external_payment_confirmation.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({
    required this.pricing,
    required this.requiresDiscountApproval,
    required this.canApproveDiscount,
    required this.requireNonCashReference,
    this.initialAttempt,
    super.key,
  });

  final CartPricing pricing;
  final bool requiresDiscountApproval;
  final bool canApproveDiscount;
  final bool requireNonCashReference;
  final CheckoutAttempt? initialAttempt;

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();
  final _cardReferenceController = TextEditingController();
  final _walletController = TextEditingController();
  final _walletReferenceController = TextEditingController();
  final _cashFocusNode = FocusNode(debugLabel: 'Cash amount');
  final _cardFocusNode = FocusNode(debugLabel: 'Card amount');
  final _walletFocusNode = FocusNode(debugLabel: 'E-wallet amount');
  bool _approved = false;
  bool _cardConfirmed = false;
  bool _walletConfirmed = false;
  bool _submitting = false;
  bool _externalPaymentSaveFailed = false;
  bool _paymentRecoveryLocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final attempt = widget.initialAttempt;
    if (attempt != null) {
      for (final tender in attempt.tenders) {
        final amount = (tender.tenderedAmountMinor / 100).toStringAsFixed(2);
        switch (tender.method) {
          case SalePaymentMethod.cash:
            _cashController.text = amount;
          case SalePaymentMethod.card:
            _cardController.text = amount;
            _cardReferenceController.text = tender.reference ?? '';
            _cardConfirmed = attempt.externalPaymentApproved;
          case SalePaymentMethod.eWallet:
            _walletController.text = amount;
            _walletReferenceController.text = tender.reference ?? '';
            _walletConfirmed = attempt.externalPaymentApproved;
        }
      }
      _externalPaymentSaveFailed = attempt.externalPaymentApproved;
      _paymentRecoveryLocked = attempt.externalPaymentApproved;
    }
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
    _cashFocusNode.dispose();
    _cardFocusNode.dispose();
    _walletFocusNode.dispose();
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f9): _submit,
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
      },
      child: FocusTraversalGroup(
        child: PopScope(
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
                          onPressed: _submitting || _paymentRecoveryLocked
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
                            onPressed: _submitting || _paymentRecoveryLocked
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
                      focusNode: _cashFocusNode,
                      autofocus: widget.initialAttempt == null,
                      enabled: !_submitting && !_paymentRecoveryLocked,
                      icon: Icons.payments_outlined,
                      onOpenNumberPad: () => _showNumberPad(
                        label: 'Cash received',
                        controller: _cashController,
                        exactAmountMinor: _cashBalance > 0
                            ? _cashBalance
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PaymentField(
                      key: const Key('card-payment-field'),
                      label: 'Card amount',
                      controller: _cardController,
                      focusNode: _cardFocusNode,
                      referenceController: _cardReferenceController,
                      enabled: !_submitting && !_paymentRecoveryLocked,
                      requireReference: widget.requireNonCashReference,
                      icon: Icons.credit_card_outlined,
                      onOpenNumberPad: () => _showNumberPad(
                        label: 'Card amount',
                        controller: _cardController,
                      ),
                    ),
                    if (_positiveAmount(_cardController) case final amount
                        when amount > 0)
                      ExternalPaymentConfirmation(
                        key: const Key('card-payment-confirmation'),
                        methodLabel: 'Card',
                        amountMinor: amount,
                        confirmed: _cardConfirmed,
                        onChanged: _submitting || _paymentRecoveryLocked
                            ? null
                            : (value) => setState(() => _cardConfirmed = value),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    _PaymentField(
                      key: const Key('wallet-payment-field'),
                      label: 'QR / E-wallet amount',
                      controller: _walletController,
                      focusNode: _walletFocusNode,
                      referenceController: _walletReferenceController,
                      enabled: !_submitting && !_paymentRecoveryLocked,
                      requireReference: widget.requireNonCashReference,
                      icon: Icons.account_balance_wallet_outlined,
                      onOpenNumberPad: () => _showNumberPad(
                        label: 'QR / E-wallet amount',
                        controller: _walletController,
                      ),
                    ),
                    if (_positiveAmount(_walletController) case final amount
                        when amount > 0)
                      ExternalPaymentConfirmation(
                        key: const Key('wallet-payment-confirmation'),
                        methodLabel: 'QR / E-wallet',
                        amountMinor: amount,
                        confirmed: _walletConfirmed,
                        onChanged: _submitting || _paymentRecoveryLocked
                            ? null
                            : (value) =>
                                  setState(() => _walletConfirmed = value),
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
                onPressed: _submitting ? null : _cancel,
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
        ),
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
        .checkout(
          tenders: tenders,
          approveDiscountAsManager: _approved,
          externalPaymentsConfirmed: tenders
              .where((tender) => tender.method != SalePaymentMethod.cash)
              .every(
                (tender) => switch (tender.method) {
                  SalePaymentMethod.card => _cardConfirmed,
                  SalePaymentMethod.eWallet => _walletConfirmed,
                  SalePaymentMethod.cash => true,
                },
              ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (checkout) => Navigator.pop(context, checkout),
      onFailure: (failure) => setState(() {
        _submitting = false;
        final hasExternal = tenders.any(
          (tender) => tender.method != SalePaymentMethod.cash,
        );
        _externalPaymentSaveFailed = _externalPaymentSaveFailed || hasExternal;
        _paymentRecoveryLocked = _paymentRecoveryLocked || hasExternal;
        _error = failure.message;
      }),
    );
  }

  void _cancel() {
    if (!_submitting && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _showNumberPad({
    required String label,
    required TextEditingController controller,
    int? exactAmountMinor,
  }) async {
    if (_submitting || _paymentRecoveryLocked) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => Semantics(
                      liveRegion: true,
                      label:
                          '$label ${value.text.isEmpty ? 'empty' : value.text}',
                      child: Text(
                        value.text.isEmpty ? 'PHP 0.00' : 'PHP ${value.text}',
                        key: const Key('number-pad-value'),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppNumberPad(
                    onInput: (value) => _insertAmount(controller, value),
                    onBackspace: () => _backspace(controller),
                    onClear: controller.clear,
                  ),
                  if (exactAmountMinor != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('number-pad-exact'),
                      onPressed: () =>
                          _setMinorAmount(controller, exactAmountMinor),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.price_check_outlined),
                      label: Text(
                        'Exact ${Formatters.currencyMinor(exactAmountMinor)}',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    key: const Key('number-pad-done'),
                    onPressed: () => Navigator.pop(sheetContext),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) {
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  void _insertAmount(TextEditingController controller, String input) {
    final current = controller.value;
    final selection = current.selection.isValid
        ? current.selection
        : TextSelection.collapsed(offset: current.text.length);
    final start = selection.start.clamp(0, current.text.length);
    final end = selection.end.clamp(0, current.text.length);
    var next = current.text.replaceRange(start, end, input);
    final prefixedZero = next.startsWith('.');
    if (prefixedZero) next = '0$next';
    if (!CurrencyTextInputFormatter.isValid(next)) return;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: start + input.length + (prefixedZero ? 1 : 0),
      ),
    );
  }

  void _backspace(TextEditingController controller) {
    final current = controller.value;
    if (current.text.isEmpty) return;
    final selection = current.selection.isValid
        ? current.selection
        : TextSelection.collapsed(offset: current.text.length);
    final start = selection.start.clamp(0, current.text.length);
    final end = selection.end.clamp(0, current.text.length);
    final removeStart = start == end && start > 0 ? start - 1 : start;
    final next = current.text.replaceRange(removeStart, end, '');
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: removeStart),
    );
  }

  void _setMinorAmount(TextEditingController controller, int amountMinor) {
    final text = (amountMinor / 100).toStringAsFixed(2);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
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
    required this.focusNode,
    required this.onOpenNumberPad,
    this.autofocus = false,
    this.requireReference = false,
    this.referenceController,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final TextEditingController? referenceController;
  final IconData icon;
  final bool enabled;
  final FocusNode focusNode;
  final VoidCallback onOpenNumberPad;
  final bool autofocus;
  final bool requireReference;

  @override
  Widget build(BuildContext context) {
    final amount = TextField(
      enabled: enabled,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [CurrencyTextInputFormatter()],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'PHP ',
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          tooltip: 'Open $label keypad',
          onPressed: enabled ? onOpenNumberPad : null,
          icon: const Icon(Icons.dialpad_outlined),
        ),
      ),
    );
    if (referenceController == null) return amount;
    final reference = TextField(
      enabled: enabled,
      controller: referenceController,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
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
