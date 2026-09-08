import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../shifts/presentation/providers/shift_providers.dart';
import '../../../hardware/domain/entities/register_hardware_profile.dart';
import '../../../customers/presentation/widgets/customer_checkout_selector.dart';
import '../../../customers/presentation/providers/customers_providers.dart';
import '../../../settings/domain/entities/operational_setting.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/sale.dart';
import '../controllers/cart_controller.dart';
import '../providers/pos_providers.dart';
import '../widgets/cart_panel.dart';
import '../widgets/discount_policy_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/product_search_panel.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/held_carts_dialog.dart';
import '../widgets/terminal_status_strip.dart';
import '../widgets/terminal_workspace.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({
    super.key,
    this.terminalLayout = true,
    this.onShift,
    this.onTransactions,
  });
  final bool terminalLayout;
  final VoidCallback? onShift;
  final VoidCallback? onTransactions;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  String _search = '';
  String? _categoryId;
  bool _paymentOpen = false;
  String? _lastSubmittedBarcode;
  DateTime? _lastSubmittedAt;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activePosSessionProvider);
    final productQuery = (search: _search, categoryId: _categoryId);
    final products = ref.watch(saleProductBrowserProvider(productQuery));
    final shift = ref.watch(activeShiftProvider).value;
    final shiftPolicy = ref.watch(shiftPolicyProvider).value;
    final checkoutAllowed =
        shift != null || (shiftPolicy?.allowSalesWithoutOpenShift ?? false);
    final canManagePolicy = session?.can(AppPermission.manageSettings) ?? false;
    final canViewCustomers = session?.can(AppPermission.viewCustomers) ?? false;
    final scannerType = ref
        .watch(activeRegisterHardwareProfileProvider)
        .value
        ?.scannerType;
    final hardware = ref.watch(activeRegisterHardwareProfileProvider).value;
    final syncState = ref.watch(syncStateProvider).asData?.value;
    ref.listen(barcodeScansProvider, (previous, next) {
      next.whenData((scan) => unawaited(_submitBarcode(scan.value)));
    });
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handleTerminalKey(node, event, scannerType),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < AppBreakpoints.tablet;
          final fullHeight =
              widget.terminalLayout &&
              constraints.maxHeight >= (compact ? 560 : 600);
          final padding = compact ? AppSpacing.lg : AppSpacing.xxl;
          final productPanel = ProductSearchPanel(
            searchController: _searchController,
            focusNode: _searchFocusNode,
            products: products,
            onSearchChanged: _onSearchChanged,
            onSubmitted: _onSubmitted,
            onRetry: () =>
                ref.invalidate(saleProductBrowserProvider(productQuery)),
            fillHeight: fullHeight,
            categoryId: _categoryId,
            onCategoryChanged: (value) => setState(() => _categoryId = value),
          );
          final cartPanel = CartPanel(
            checkoutAllowed: checkoutAllowed,
            onCheckout: _checkout,
            onHold: _holdCart,
            onResume: _resumeCart,
            onClear: _confirmClear,
            fillHeight: fullHeight && !compact,
          );
          if (fullHeight) {
            final cart = ref.watch(cartControllerProvider);
            final pricing = ref.watch(cartPricingProvider);
            return TerminalWorkspace(
              compact: compact,
              status: TerminalStatusStrip(
                branchName: session?.activeBranch.branch.name ?? 'No branch',
                registerName: shift?.registerName ?? 'No open register',
                cashierName: session?.user.displayName ?? 'No cashier',
                shiftOpen: shift != null,
                syncState: syncState,
                scannerType: hardware?.scannerType,
                printerType: hardware?.printerType,
              ),
              toolbar: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (ref.watch(cartPersistenceFailureProvider) != null)
                      const Padding(
                        padding: EdgeInsets.only(right: AppSpacing.md),
                        child: Text('Cart not saved — check device storage'),
                      ),
                    if (widget.onShift != null)
                      OutlinedButton.icon(
                        onPressed: widget.onShift,
                        icon: const Icon(Icons.point_of_sale_outlined),
                        label: Text(
                          shift == null ? 'Open shift' : 'Shift & cash',
                        ),
                      ),
                    if (widget.onTransactions != null)
                      TextButton.icon(
                        onPressed: widget.onTransactions,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Transactions'),
                      ),
                    if (canViewCustomers)
                      TextButton.icon(
                        onPressed:
                            cart.checkoutAttempt?.externalPaymentApproved ==
                                true
                            ? null
                            : _chooseCustomer,
                        icon: const Icon(Icons.person_outline),
                        label: Text(
                          cart.customerId == null
                              ? 'Customer · F8'
                              : 'Change customer · F8',
                        ),
                      ),
                    if (cart.customerId != null)
                      IconButton(
                        tooltip: 'Remove customer',
                        onPressed:
                            cart.checkoutAttempt?.externalPaymentApproved ==
                                true
                            ? null
                            : () {
                                final result = ref
                                    .read(cartControllerProvider.notifier)
                                    .setCustomer(null);
                                if (result.isSuccess) {
                                  ref
                                          .read(
                                            selectedCheckoutCustomerProvider
                                                .notifier,
                                          )
                                          .state =
                                      null;
                                }
                              },
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    TextButton.icon(
                      onPressed: _resumeCart,
                      icon: const Icon(Icons.history),
                      label: const Text('Held sales · F4'),
                    ),
                    if (canManagePolicy)
                      IconButton(
                        tooltip: 'Discount policy',
                        onPressed: _openPolicy,
                        icon: const Icon(Icons.tune),
                      ),
                  ],
                ),
              ),
              products: productPanel,
              cart: cartPanel,
              cartSummary: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('pos-cart-summary'),
                        onPressed: () => _showCartSheet(checkoutAllowed),
                        icon: Badge(
                          label: Text('${cart.lines.length}'),
                          child: const Icon(Icons.shopping_cart_outlined),
                        ),
                        label: Text(
                          pricing == null
                              ? 'View cart'
                              : Formatters.currencyMinor(pricing.totalMinor),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: checkoutAllowed && pricing != null
                            ? _checkout
                            : widget.onShift,
                        child: Text(
                          checkoutAllowed ? 'Pay · F9' : 'Open shift',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
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
                    TerminalStatusStrip(
                      branchName:
                          session?.activeBranch.branch.name ?? 'No branch',
                      registerName: shift?.registerName ?? 'No open register',
                      cashierName: session?.user.displayName ?? 'No cashier',
                      shiftOpen: shift != null,
                      syncState: syncState,
                      scannerType: hardware?.scannerType,
                      printerType: hardware?.printerType,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _CheckoutHeader(
                      hasOpenShift: shift != null,
                      bypassEnabled:
                          shiftPolicy?.allowSalesWithoutOpenShift ?? false,
                      canManagePolicy: canManagePolicy,
                      onPolicy: _openPolicy,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (canViewCustomers) ...[
                      const CustomerCheckoutSelector(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (compact)
                      Column(
                        children: [
                          productPanel,
                          const SizedBox(height: AppSpacing.lg),
                          cartPanel,
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: productPanel),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(flex: 5, child: cartPanel),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  Future<void> _onSubmitted(String value) async {
    await _submitBarcode(value);
  }

  Future<void> _submitBarcode(String value) async {
    if (_paymentOpen) return;
    _debounce?.cancel();
    final barcode = value.trim();
    if (barcode.isEmpty) return;
    final now = DateTime.now().toUtc();
    final lastSubmittedAt = _lastSubmittedAt;
    if (_lastSubmittedBarcode == barcode &&
        lastSubmittedAt != null &&
        now.difference(lastSubmittedAt) <= const Duration(milliseconds: 500)) {
      return;
    }
    _lastSubmittedBarcode = barcode;
    _lastSubmittedAt = now;
    setState(() => _search = barcode);
    final products = await ref.read(saleProductSearchProvider(barcode).future);
    if (!mounted || products.isEmpty) return;
    final normalized = barcode.replaceAll(RegExp(r'[\s-]+'), '');
    final exact = products.where(
      (product) => [
        if (product.primaryBarcode != null) product.primaryBarcode!,
        ...product.barcodes,
      ].any((value) => value.replaceAll(RegExp(r'[\s-]+'), '') == normalized),
    );
    if (exact.length == 1) {
      final result = ref
          .read(cartControllerProvider.notifier)
          .addProduct(exact.single);
      if (result.failureOrNull case final failure?) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
      _searchController.clear();
      setState(() => _search = '');
    }
  }

  KeyEventResult _handleScannerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = switch (event.logicalKey) {
      LogicalKeyboardKey.enter => 'Enter',
      LogicalKeyboardKey.numpadEnter => 'Numpad Enter',
      LogicalKeyboardKey.tab => 'Tab',
      LogicalKeyboardKey.backspace => 'Backspace',
      _ => event.character,
    };
    if (key != null) ref.read(keyboardWedgeScannerProvider).acceptKey(key);
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleTerminalKey(
    FocusNode node,
    KeyEvent event,
    BarcodeScannerType? scannerType,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final cart = ref.read(cartControllerProvider);
    final recoveryLocked =
        cart.checkoutAttempt?.externalPaymentApproved == true;
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f4) {
      if (recoveryLocked) {
        _showRecoveryLockMessage();
      } else if (cart.isEmpty) {
        unawaited(_resumeCart());
      } else {
        unawaited(_holdCart());
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f8) {
      if (recoveryLocked) {
        _showRecoveryLockMessage();
      } else {
        unawaited(_chooseCustomer());
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f9) {
      unawaited(_checkout());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (recoveryLocked) {
        _showRecoveryLockMessage();
      } else {
        unawaited(_confirmClear());
      }
      return KeyEventResult.handled;
    }
    if (scannerType == BarcodeScannerType.disabled ||
        scannerType == BarcodeScannerType.camera) {
      return KeyEventResult.ignored;
    }
    return _handleScannerKey(node, event);
  }

  void _showRecoveryLockMessage() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the saved payment recovery before changing this sale.',
          ),
        ),
      );
  }

  Future<void> _checkout() async {
    if (_paymentOpen) return;
    _paymentOpen = true;
    try {
      await _openPayment();
    } finally {
      _paymentOpen = false;
    }
    if (mounted) _searchFocusNode.requestFocus();
  }

  Future<void> _openPayment() async {
    final refreshed = await ref.read(cartControllerProvider.notifier).refresh();
    if (!mounted) return;
    if (refreshed.failureOrNull case final failure?) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    final pricing = ref.read(cartPricingProvider);
    if (pricing == null) {
      if (mounted && !ref.read(cartControllerProvider).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Resolve unavailable products, prices, or stock before payment.',
            ),
          ),
        );
      }
      return;
    }
    final policy = await ref.read(discountPolicyProvider.future);
    if (!mounted) return;
    final threshold = policy?.approvalThresholdBasisPoints;
    final requiresApproval =
        threshold != null &&
        pricing.discountMinor * 10000 > pricing.subtotalMinor * threshold;
    final session = ref.read(activePosSessionProvider);
    final result = await showDialog<CheckoutResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog(
        pricing: pricing,
        requireNonCashReference:
            ref
                .read(operationalSettingsProvider)
                .asData
                ?.value
                .boolean(OperationalSettingKey.salesRequireNonCashReference) ??
            false,
        requiresDiscountApproval: requiresApproval,
        canApproveDiscount:
            session?.can(AppPermission.approveSaleDiscounts) ?? false,
        initialAttempt: ref.read(cartControllerProvider).checkoutAttempt,
      ),
    );
    if (result == null || !mounted) return;
    final sale = await ref.read(saleDetailsProvider(result.saleId).future);
    if (!mounted || sale == null) return;
    unawaited(
      ref.read(deliverSaleReceiptUseCaseProvider)(
        session: ref.read(activePosSessionProvider),
        sale: sale,
        isReprint: false,
      ),
    );
    unawaited(
      ref.read(openSaleCashDrawerUseCaseProvider)(
        session: ref.read(activePosSessionProvider),
        sale: sale,
      ),
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptDialog(sale: sale),
    );
  }

  Future<void> _holdCart() async {
    if (ref.read(cartControllerProvider).isEmpty) return;
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const HoldCartDialog(),
    );
    if (title == null || !mounted) return;
    final result = await ref
        .read(cartControllerProvider.notifier)
        .hold(title: title);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale held on this terminal.')),
      ),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _resumeCart() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const HeldCartsDialog(),
    );
  }

  Future<void> _chooseCustomer() async {
    if (!(ref
            .read(activePosSessionProvider)
            ?.can(AppPermission.viewCustomers) ??
        false)) {
      return;
    }
    final customer = await showCustomerLookupDialog(context, ref);
    if (customer == null || !mounted) return;
    final result = ref
        .read(cartControllerProvider.notifier)
        .setCustomer(customer.id);
    result.fold(
      onSuccess: (_) {
        ref.read(selectedCheckoutCustomerProvider.notifier).state = customer;
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _showCartSheet(bool checkoutAllowed) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: CartPanel(
            checkoutAllowed: checkoutAllowed,
            onClear: _confirmClear,
            onCheckout: () {
              Navigator.pop(sheetContext);
              unawaited(_checkout());
            },
            onHold: () {
              Navigator.pop(sheetContext);
              unawaited(_holdCart());
            },
            onResume: () {
              Navigator.pop(sheetContext);
              unawaited(_resumeCart());
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    if (ref.read(cartControllerProvider).isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear current sale?'),
        content: const Text('This removes all items from the active cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep sale'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear sale'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final result = ref.read(cartControllerProvider.notifier).clear();
      result.fold(
        onSuccess: (_) {
          ref.read(selectedCheckoutCustomerProvider.notifier).state = null;
        },
        onFailure: (failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        },
      );
    }
  }

  Future<void> _openPolicy() async {
    final policy = await ref.read(discountPolicyProvider.future);
    if (!mounted || policy == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DiscountPolicyDialog(policy: policy),
    );
    if (saved == true) ref.invalidate(discountPolicyProvider);
  }
}

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader({
    required this.hasOpenShift,
    required this.bypassEnabled,
    required this.canManagePolicy,
    required this.onPolicy,
  });

  final bool hasOpenShift;
  final bool bypassEnabled;
  final bool canManagePolicy;
  final VoidCallback onPolicy;

  @override
  Widget build(BuildContext context) {
    final ready = hasOpenShift || bypassEnabled;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Point of sale',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ready
                    ? hasOpenShift
                          ? 'Register ready. Sales are saved locally before synchronization.'
                          : 'Shift bypass policy is active for this branch.'
                    : 'Open a shift in Register & shift before accepting a sale.',
              ),
            ],
          ),
        ),
        Chip(
          avatar: Icon(
            ready ? Icons.check_circle_outline : Icons.lock_outline,
            size: 18,
          ),
          label: Text(ready ? 'Ready' : 'Shift required'),
        ),
        if (canManagePolicy)
          OutlinedButton.icon(
            onPressed: onPolicy,
            icon: const Icon(Icons.percent_outlined),
            label: const Text('Discount policy'),
          ),
      ],
    );
  }
}
