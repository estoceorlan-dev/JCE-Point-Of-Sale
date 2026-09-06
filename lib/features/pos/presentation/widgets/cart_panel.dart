import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/cart.dart';
import '../../domain/value_objects/cart_pricing.dart';
import '../controllers/cart_controller.dart';
import 'cart_edit_dialogs.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({
    required this.checkoutAllowed,
    required this.onCheckout,
    required this.onHold,
    required this.onResume,
    this.onClear,
    this.fillHeight = false,
    super.key,
  });

  final bool checkoutAllowed;
  final VoidCallback onCheckout;
  final VoidCallback onHold;
  final VoidCallback onResume;
  final VoidCallback? onClear;
  final bool fillHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final pricing = ref.watch(cartPricingProvider);
    final lines = ListView.separated(
      shrinkWrap: !fillHeight,
      itemCount: cart.lines.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _CartLineTile(
        line: cart.lines[index],
        pricedLine: pricing?.lines[index],
        onQuantity: () => _quantity(context, ref, cart.lines[index]),
        onDecrease: () => _decrease(context, ref, cart.lines[index]),
        onIncrease: () => _increase(context, ref, cart.lines[index]),
        onDiscount: () => _itemDiscount(context, ref, cart.lines[index]),
        onRemove: () => ref
            .read(cartControllerProvider.notifier)
            .removeProduct(cart.lines[index].product.id),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current sale',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!cart.isEmpty)
                  IconButton(
                    tooltip: 'Hold sale (F4)',
                    onPressed: onHold,
                    icon: const Icon(Icons.pause_circle_outline),
                  ),
                IconButton(
                  tooltip: 'Resume held sale (F4)',
                  onPressed: onResume,
                  icon: const Icon(Icons.history),
                ),
                if (!cart.isEmpty)
                  TextButton.icon(
                    onPressed: onClear ?? () => _confirmClear(context, ref),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 44),
                    SizedBox(height: AppSpacing.md),
                    Text('Scan or select a product to begin.'),
                  ],
                ),
              )
            else ...[
              if (fillHeight)
                Expanded(child: lines)
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 390),
                  child: lines,
                ),
              const Divider(height: AppSpacing.xl),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('sale-discount-button'),
                  onPressed: () => _saleDiscount(context, ref, cart),
                  icon: const Icon(Icons.percent_outlined),
                  label: Text(
                    cart.saleDiscountMinor == 0
                        ? 'Add sale discount'
                        : 'Sale discount: ${Formatters.currencyMinor(cart.saleDiscountMinor)}',
                  ),
                ),
              ),
              if (pricing case final value?) ...[
                _AmountRow(label: 'Subtotal', amountMinor: value.subtotalMinor),
                if (value.discountMinor > 0)
                  _AmountRow(
                    label: 'Discount',
                    amountMinor: -value.discountMinor,
                  ),
                _AmountRow(label: 'Tax', amountMinor: value.taxMinor),
                const Divider(),
                _AmountRow(
                  label: 'Total',
                  amountMinor: value.totalMinor,
                  emphasized: true,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const Key('checkout-button'),
                onPressed: pricing != null && checkoutAllowed
                    ? onCheckout
                    : null,
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  checkoutAllowed ? 'Take payment' : 'Open shift to continue',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _quantity(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => QuantityDialog(quantityMilli: line.quantityMilli),
    );
    if (value == null || !context.mounted) return;
    _showFailure(
      context,
      ref
          .read(cartControllerProvider.notifier)
          .setQuantity(line.product.id, value),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear current sale?'),
        content: const Text('All items will be removed from this cart.'),
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
    if (confirmed == true) ref.read(cartControllerProvider.notifier).clear();
  }

  void _decrease(BuildContext context, WidgetRef ref, CartLine line) {
    if (line.quantityMilli <= 1000) {
      ref.read(cartControllerProvider.notifier).removeProduct(line.product.id);
      return;
    }
    _showFailure(
      context,
      ref
          .read(cartControllerProvider.notifier)
          .setQuantity(line.product.id, line.quantityMilli - 1000),
    );
  }

  void _increase(BuildContext context, WidgetRef ref, CartLine line) {
    _showFailure(
      context,
      ref
          .read(cartControllerProvider.notifier)
          .setQuantity(line.product.id, line.quantityMilli + 1000),
    );
  }

  Future<void> _itemDiscount(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    final input = await showDialog<DiscountInput>(
      context: context,
      builder: (context) => DiscountDialog(
        title: 'Discount ${line.product.name}',
        currentAmountMinor: line.itemDiscountMinor,
        currentReason: line.discountReason,
      ),
    );
    if (input == null || !context.mounted) return;
    _showFailure(
      context,
      ref
          .read(cartControllerProvider.notifier)
          .setItemDiscount(
            productId: line.product.id,
            amountMinor: input.amountMinor,
            reason: input.reason,
          ),
    );
  }

  Future<void> _saleDiscount(
    BuildContext context,
    WidgetRef ref,
    Cart cart,
  ) async {
    final input = await showDialog<DiscountInput>(
      context: context,
      builder: (context) => DiscountDialog(
        title: 'Sale discount',
        currentAmountMinor: cart.saleDiscountMinor,
        currentReason: cart.saleDiscountReason,
      ),
    );
    if (input == null || !context.mounted) return;
    _showFailure(
      context,
      ref
          .read(cartControllerProvider.notifier)
          .setSaleDiscount(
            amountMinor: input.amountMinor,
            reason: input.reason,
          ),
    );
  }

  void _showFailure(BuildContext context, Result<void, Failure> result) {
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.pricedLine,
    required this.onQuantity,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDiscount,
    required this.onRemove,
  });

  final CartLine line;
  final PricedCartLine? pricedLine;
  final VoidCallback onQuantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDiscount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.product.name),
                    Text(
                      '${line.product.sku} · ${Formatters.currencyMinor(line.product.unitPriceMinor)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (line.validationMessage case final message?)
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                Formatters.currencyMinor(pricedLine?.totalAmountMinor ?? 0),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              IconButton(
                tooltip: 'Remove item',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Decrease quantity',
                onPressed: onDecrease,
                icon: const Icon(Icons.remove),
              ),
              TextButton(
                onPressed: onQuantity,
                child: Text(
                  '${Formatters.quantityMilli(line.quantityMilli)} ${line.product.unitName}',
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Increase quantity',
                onPressed: onIncrease,
                icon: const Icon(Icons.add),
              ),
              TextButton.icon(
                onPressed: onDiscount,
                icon: const Icon(Icons.percent_outlined, size: 18),
                label: Text(
                  line.itemDiscountMinor == 0
                      ? 'Discount'
                      : '-${Formatters.currencyMinor(line.itemDiscountMinor)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amountMinor,
    this.emphasized = false,
  });

  final String label;
  final int amountMinor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(Formatters.currencyMinor(amountMinor), style: style),
        ],
      ),
    );
  }
}
