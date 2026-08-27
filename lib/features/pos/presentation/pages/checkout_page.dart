import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../shifts/presentation/providers/shift_providers.dart';
import '../../domain/entities/sale.dart';
import '../controllers/cart_controller.dart';
import '../providers/pos_providers.dart';
import '../widgets/cart_panel.dart';
import '../widgets/discount_policy_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/product_search_panel.dart';
import '../widgets/receipt_dialog.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activePosSessionProvider);
    final products = ref.watch(saleProductSearchProvider(_search));
    final shift = ref.watch(activeShiftProvider).value;
    final shiftPolicy = ref.watch(shiftPolicyProvider).value;
    final checkoutAllowed =
        shift != null || (shiftPolicy?.allowSalesWithoutOpenShift ?? false);
    final canManagePolicy = session?.can(AppPermission.manageSettings) ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.compact;
        final padding = compact ? AppSpacing.lg : AppSpacing.xxl;
        final productPanel = ProductSearchPanel(
          searchController: _searchController,
          products: products,
          onSearchChanged: _onSearchChanged,
          onSubmitted: _onSubmitted,
        );
        final cartPanel = CartPanel(
          checkoutAllowed: checkoutAllowed,
          onCheckout: _checkout,
        );
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
                  _CheckoutHeader(
                    hasOpenShift: shift != null,
                    bypassEnabled:
                        shiftPolicy?.allowSalesWithoutOpenShift ?? false,
                    canManagePolicy: canManagePolicy,
                    onPolicy: _openPolicy,
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  Future<void> _onSubmitted(String value) async {
    _debounce?.cancel();
    setState(() => _search = value.trim());
    final products = await ref.read(
      saleProductSearchProvider(value.trim()).future,
    );
    if (!mounted || products.isEmpty) return;
    final normalized = value.replaceAll(RegExp(r'[\s-]+'), '');
    final exact = products.where(
      (product) =>
          product.primaryBarcode?.replaceAll(RegExp(r'[\s-]+'), '') ==
          normalized,
    );
    if (exact.length == 1) {
      ref.read(cartControllerProvider.notifier).addProduct(exact.single);
      _searchController.clear();
      setState(() => _search = '');
    }
  }

  Future<void> _checkout() async {
    final pricing = ref.read(cartPricingProvider);
    if (pricing == null) return;
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
        requiresDiscountApproval: requiresApproval,
        canApproveDiscount:
            session?.can(AppPermission.approveSaleDiscounts) ?? false,
      ),
    );
    if (result == null || !mounted) return;
    final sale = await ref.read(saleDetailsProvider(result.saleId).future);
    if (!mounted || sale == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptDialog(sale: sale),
    );
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
