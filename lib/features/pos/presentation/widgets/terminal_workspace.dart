import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';

class TerminalWorkspace extends StatelessWidget {
  const TerminalWorkspace({
    super.key,
    required this.status,
    required this.toolbar,
    required this.products,
    required this.cart,
    required this.compact,
    required this.cartSummary,
  });
  final Widget status;
  final Widget toolbar;
  final Widget products;
  final Widget cart;
  final Widget cartSummary;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        status,
        const SizedBox(height: AppSpacing.sm),
        toolbar,
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: compact
              ? products
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: products),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 5, child: cart),
                  ],
                ),
        ),
        if (compact) ...[const SizedBox(height: AppSpacing.sm), cartSummary],
      ],
    ),
  );
}
