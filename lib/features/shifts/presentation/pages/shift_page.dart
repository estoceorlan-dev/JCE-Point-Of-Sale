import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../domain/entities/cash_shift.dart';
import '../../domain/entities/register.dart';
import '../controllers/shift_mutation_controller.dart';
import '../providers/shift_providers.dart';
import '../widgets/active_shift_panel.dart';
import '../widgets/cash_movement_dialog.dart';
import '../widgets/close_shift_dialog.dart';
import '../widgets/open_shift_dialog.dart';
import '../widgets/recent_shifts_panel.dart';
import '../widgets/register_dialog.dart';
import '../widgets/register_setup_panel.dart';
import '../widgets/shift_policy_dialog.dart';

class ShiftPage extends ConsumerWidget {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeShiftSessionProvider);
    final deviceIdAsync = ref.watch(currentDeviceIdProvider);
    final registers = ref.watch(registersProvider).value ?? const <Register>[];
    final activeShift = ref.watch(activeShiftProvider).value;
    final recentShifts =
        ref.watch(recentShiftsProvider).value ?? const <CashShift>[];
    final canManage = session?.can(AppPermission.manageRegisters) ?? false;
    final actorUserId = session?.activeOrganization.appUserId;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < AppBreakpoints.compact
            ? AppSpacing.lg
            : AppSpacing.xxl;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  canManage: canManage,
                  canOpen:
                      deviceIdAsync.value != null &&
                      activeShift == null &&
                      registers.any(
                        (register) =>
                            register.isActive &&
                            register.isAssignedTo(deviceIdAsync.value!),
                      ),
                  onNewRegister: () => _newRegister(context),
                  onPolicy: () => _policy(context, ref),
                  onOpenShift: () =>
                      _openShift(context, deviceIdAsync.value!, registers),
                ),
                const SizedBox(height: AppSpacing.xl),
                deviceIdAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Text('Device identity unavailable: $error'),
                  data: (deviceId) => Column(
                    children: [
                      if (activeShift case final shift?)
                        ActiveShiftPanel(
                          shift: shift,
                          isCurrentUser: shift.openedByUserId == actorUserId,
                          onCashMovement: () => _movement(context, shift.id),
                          onClose: () => _close(context, shift),
                        )
                      else
                        RegisterSetupPanel(
                          registers: registers,
                          deviceId: deviceId,
                          canManage: canManage,
                          onAssign: (register) =>
                              _assign(context, ref, register),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      RecentShiftsPanel(shifts: recentShifts),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _newRegister(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RegisterDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Register created.')));
    }
  }

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    Register register,
  ) async {
    final result = await ref
        .read(shiftMutationControllerProvider.notifier)
        .assignCurrentDevice(register);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${register.name} assigned to this device.')),
      ),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _openShift(
    BuildContext context,
    String deviceId,
    List<Register> registers,
  ) async {
    final opened = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OpenShiftDialog(
        deviceId: deviceId,
        registers: registers
            .where(
              (register) =>
                  register.isActive && register.isAssignedTo(deviceId),
            )
            .toList(growable: false),
      ),
    );
    if (opened == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift opened and saved offline.')),
      );
    }
  }

  Future<void> _movement(BuildContext context, String shiftId) async {
    final posted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CashMovementDialog(shiftId: shiftId),
    );
    if (posted == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Drawer movement posted.')));
    }
  }

  Future<void> _close(BuildContext context, CashShift shift) async {
    final closed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CloseShiftDialog(shift: shift),
    );
    if (closed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift closed and queued for sync.')),
      );
    }
  }

  Future<void> _policy(BuildContext context, WidgetRef ref) async {
    final policy = await ref.read(shiftPolicyProvider.future);
    if (!context.mounted || policy == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShiftPolicyDialog(policy: policy),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shift policy updated.')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.canManage,
    required this.canOpen,
    required this.onNewRegister,
    required this.onPolicy,
    required this.onOpenShift,
  });

  final bool canManage;
  final bool canOpen;
  final VoidCallback onNewRegister;
  final VoidCallback onPolicy;
  final VoidCallback onOpenShift;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register & shift',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Recoverable offline cash sessions with immutable drawer movements.',
              ),
            ],
          ),
        ),
        if (canManage)
          OutlinedButton.icon(
            onPressed: onNewRegister,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('New register'),
          ),
        if (canManage)
          OutlinedButton.icon(
            onPressed: onPolicy,
            icon: const Icon(Icons.policy_outlined),
            label: const Text('Policy'),
          ),
        FilledButton.icon(
          onPressed: canOpen ? onOpenShift : null,
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Open shift'),
        ),
      ],
    );
  }
}
