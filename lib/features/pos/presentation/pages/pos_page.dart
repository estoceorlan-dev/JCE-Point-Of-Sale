import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/app_config.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../shifts/presentation/pages/shift_page.dart';
import 'checkout_page.dart';
import 'sales_history_page.dart';

class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider).value ?? const [];
    final terminalFlag = flags.where((flag) => flag.key == 'pos.terminal');
    final terminalEnabled = terminalFlag.isNotEmpty
        ? terminalFlag.last.isEnabled
        : ref.watch(appConfigProvider).enableDemoAuth;
    if (terminalEnabled) {
      return CheckoutPage(
        onShift: () =>
            _openWorkspace(context, 'Shift & cash', const ShiftPage()),
        onTransactions: () =>
            _openWorkspace(context, 'Transactions', const SalesHistoryPage()),
      );
    }
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
              children: [
                CheckoutPage(terminalLayout: false),
                ShiftPage(),
                SalesHistoryPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWorkspace(
    BuildContext context,
    String title,
    Widget child,
  ) => showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            tooltip: 'Back to terminal',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        body: child,
      ),
    ),
  );
}
