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
    required this.onConfigureHardware,
    required this.onEdit,
    required this.onArchive,
    required this.onUnassign,
  });

  final List<Register> registers;
  final String deviceId;
  final bool canManage;
  final ValueChanged<Register> onAssign;
  final ValueChanged<Register> onConfigureHardware;
  final ValueChanged<Register> onEdit;
  final ValueChanged<Register> onArchive;
  final ValueChanged<Register> onUnassign;

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
                    !register.isActive
                        ? 'Archived'
                        : register.assignedDeviceId == null
                        ? 'No device assigned'
                        : register.isAssignedTo(deviceId)
                        ? 'Assigned to this device'
                        : 'Assigned to another device',
                  ),
                  trailing: canManage
                      ? Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            if (register.isActive)
                              OutlinedButton.icon(
                                onPressed: () => onConfigureHardware(register),
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('Hardware'),
                              ),
                            if (register.isActive &&
                                !register.isAssignedTo(deviceId))
                              OutlinedButton(
                                onPressed: () => onAssign(register),
                                child: const Text('Assign this device'),
                              ),
                            PopupMenuButton<String>(
                              tooltip: 'Manage register',
                              onSelected: (action) {
                                if (action == 'edit') onEdit(register);
                                if (action == 'archive') onArchive(register);
                                if (action == 'unassign') onUnassign(register);
                              },
                              itemBuilder: (_) => [
                                if (register.isActive)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                if (register.isActive &&
                                    register.assignedDeviceId != null)
                                  const PopupMenuItem(
                                    value: 'unassign',
                                    child: Text('Unassign device'),
                                  ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text(
                                    register.isActive ? 'Archive' : 'Restore',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}
