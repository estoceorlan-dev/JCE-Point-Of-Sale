import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../shifts/presentation/providers/shift_providers.dart';
import '../controllers/cart_controller.dart';
import '../providers/pos_providers.dart';

class HeldCartsDialog extends ConsumerWidget {
  const HeldCartsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carts = ref.watch(heldCartsProvider);
    return AlertDialog(
      title: const Text('Held sales'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: carts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Held carts unavailable: $error')),
          data: (items) => items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause_circle_outline, size: 42),
                      SizedBox(height: AppSpacing.md),
                      Text('No held sales on this terminal.'),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cart = items[index];
                    return ListTile(
                      leading: const Icon(Icons.shopping_cart_outlined),
                      title: Text(cart.title),
                      subtitle: Text(
                        '${cart.itemCount} products · ${Formatters.quantityMilli(cart.quantityMilli)} items\n'
                        '${_formatTime(cart.updatedAt)}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Discard held sale',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final contextValue = ref.read(
                            businessContextProvider,
                          );
                          if (contextValue == null) return;
                          final deviceId = await ref.read(
                            currentDeviceIdProvider.future,
                          );
                          await ref
                              .read(posCartRepositoryProvider)
                              .deleteHeld(
                                context: contextValue,
                                deviceId: deviceId,
                                heldCartId: cart.id,
                              );
                        },
                      ),
                      onTap: () async {
                        final result = await ref
                            .read(cartControllerProvider.notifier)
                            .resume(cart.id);
                        if (!context.mounted) return;
                        result.fold(
                          onSuccess: (_) => Navigator.pop(context, true),
                          onFailure: (failure) =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(failure.message)),
                              ),
                        );
                      },
                    );
                  },
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
}

class HoldCartDialog extends StatefulWidget {
  const HoldCartDialog({super.key});

  @override
  State<HoldCartDialog> createState() => _HoldCartDialogState();
}

class _HoldCartDialogState extends State<HoldCartDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hold current sale'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Label (optional)',
        hintText: 'Customer name or reference',
      ),
      onSubmitted: (_) => Navigator.pop(context, _controller.text),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Hold sale'),
      ),
    ],
  );
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
