import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/register.dart';

class RegisterSetupPanel extends StatelessWidget {
  const RegisterSetupPanel({
    super.key,
    required this.registers,
    required this.deviceId,
    required this.canManage,
    required this.onAssign,
  });

  final List<Register> registers;
  final String deviceId;
  final bool canManage;
  final ValueChanged<Register> onAssign;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Branch registers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Current device: $deviceId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (registers.isEmpty)
              const Text('No registers are configured for this branch.')
            else
              for (final register in registers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    register.isAssignedTo(deviceId)
                        ? Icons.point_of_sale
                        : Icons.point_of_sale_outlined,
                  ),
                  title: Text('${register.code} • ${register.name}'),
                  subtitle: Text(
                    register.assignedDeviceId == null
                        ? 'No device assigned'
                        : register.isAssignedTo(deviceId)
                        ? 'Assigned to this device'
                        : 'Assigned to another device',
                  ),
                  trailing: canManage && !register.isAssignedTo(deviceId)
                      ? OutlinedButton(
                          onPressed: () => onAssign(register),
                          child: const Text('Assign this device'),
                        )
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}
