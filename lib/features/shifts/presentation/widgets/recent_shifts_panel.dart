import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/cash_shift.dart';

class RecentShiftsPanel extends StatelessWidget {
  const RecentShiftsPanel({super.key, required this.shifts});

  final List<CashShift> shifts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent shifts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            if (shifts.isEmpty)
              const Text('No shifts have been recorded for this branch.')
            else
              for (final shift in shifts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    shift.status == CashShiftStatus.open
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline,
                  ),
                  title: Text('${shift.registerName} • ${shift.status.label}'),
                  subtitle: Text(
                    shift.status == CashShiftStatus.closed
                        ? 'Expected ${Formatters.currencyMinor(shift.expectedCashMinorAtClose ?? 0)} • Counted ${Formatters.currencyMinor(shift.countedCashMinor ?? 0)}'
                        : 'Opened ${shift.openedAt.toLocal()}',
                  ),
                  trailing: shift.discrepancyMinor == null
                      ? null
                      : Text(
                          'Difference ${Formatters.currencyMinor(shift.discrepancyMinor!)}',
                        ),
                ),
          ],
        ),
      ),
    );
  }
}
