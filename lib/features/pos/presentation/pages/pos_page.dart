import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../shifts/presentation/pages/shift_page.dart';
import 'checkout_page.dart';
import 'sales_history_page.dart';

class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(
                    icon: Icon(Icons.point_of_sale_outlined),
                    text: 'Checkout',
                  ),
                  Tab(
                    icon: Icon(Icons.storefront_outlined),
                    text: 'Register & shift',
                  ),
                  Tab(
                    icon: Icon(Icons.receipt_long_outlined),
                    text: 'Transactions',
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [CheckoutPage(), ShiftPage(), SalesHistoryPage()],
            ),
          ),
        ],
      ),
    );
  }
}
