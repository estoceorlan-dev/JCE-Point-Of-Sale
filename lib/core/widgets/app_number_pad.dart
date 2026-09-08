import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A reusable touch-sized numeric pad for decimal amount and quantity entry.
class AppNumberPad extends StatelessWidget {
  const AppNumberPad({
    required this.onInput,
    required this.onBackspace,
    required this.onClear,
    this.enabled = true,
    this.decimalEnabled = true,
    super.key,
  });

  final ValueChanged<String> onInput;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool enabled;
  final bool decimalEnabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Numeric keypad',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['.', '0', '00'],
          ]) ...[
            Row(
              children: [
                for (final value in row) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: OutlinedButton(
                        key: Key('number-pad-$value'),
                        onPressed: enabled && (value != '.' || decimalEnabled)
                            ? () => onInput(value)
                            : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: OutlinedButton.icon(
                    key: const Key('number-pad-clear'),
                    onPressed: enabled ? onClear : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: OutlinedButton.icon(
                    key: const Key('number-pad-backspace'),
                    onPressed: enabled ? onBackspace : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Backspace'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
