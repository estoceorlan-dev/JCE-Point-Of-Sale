import 'package:flutter/material.dart';

/// Controlled directory filter; null always means no restriction.
class AppFilterDropdown<T extends Object> extends StatelessWidget {
  const AppFilterDropdown({
    required this.label,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String allLabel;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      DropdownMenuItem(value: null, child: Text(allLabel)),
      for (final entry in options.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}
