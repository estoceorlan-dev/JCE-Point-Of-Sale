import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../shared/models/permission.dart';
import '../../domain/entities/cash_shift.dart';
import '../../domain/entities/register.dart';
import '../../domain/repositories/register_administration_repository.dart';
import '../controllers/shift_mutation_controller.dart';
import '../providers/shift_providers.dart';
import '../providers/register_administration_providers.dart';
import '../widgets/active_shift_panel.dart';
import '../widgets/cash_movement_dialog.dart';
import '../widgets/close_shift_dialog.dart';
import '../widgets/open_shift_dialog.dart';
import '../widgets/recent_shifts_panel.dart';
import '../widgets/register_dialog.dart';
import '../widgets/register_setup_panel.dart';
import '../widgets/shift_policy_dialog.dart';
import '../../../hardware/presentation/widgets/register_hardware_dialog.dart';

class ShiftPage extends ConsumerWidget {
  const ShiftPage({super.key, this.administrationOnly = false});

  final bool administrationOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeShiftSessionProvider);
    final deviceIdAsync = ref.watch(currentDeviceIdProvider);
    final registers = ref.watch(registersProvider).value ?? const <Register>[];
    final allRegisters = ref.watch(allRegistersProvider).value ?? registers;
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
                  administrationOnly: administrationOnly,
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
                      if (!administrationOnly && activeShift != null)
                        ActiveShiftPanel(
                          shift: activeShift,
                          isCurrentUser:
                              activeShift.openedByUserId == actorUserId,
                          onCashMovement: () =>
                              _movement(context, activeShift.id),
                          onClose: () => _close(context, activeShift),
                        ),
                      if (activeShift == null || canManage)
                        RegisterSetupPanel(
                          registers: canManage ? allRegisters : registers,
                          deviceId: deviceId,
                          canManage: canManage,
                          onAssign: (register) =>
                              _assign(context, ref, register),
                          onConfigureHardware: (register) =>
                              _hardware(context, register),
                          onEdit: (register) => showDialog<bool>(
                            context: context,
                            builder: (_) => RegisterDialog(register: register),
                          ),
                          onArchive: (register) => _administer(
                            context,
                            ref,
                            register,
                            register.isActive
                                ? RegisterAction.archive
                                : RegisterAction.restore,
                          ),
                          onUnassign: (register) => _administer(
                            context,
                            ref,
                            register,
                            RegisterAction.unassignDevice,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      if (!administrationOnly)
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

  Future<void> _administer(
    BuildContext context,
    WidgetRef ref,
    Register register,
    RegisterAction action,
  ) async {
    final label = switch (action) {
      RegisterAction.archive => 'Archive register',
      RegisterAction.restore => 'Restore register',
      RegisterAction.unassignDevice => 'Unassign device',
      RegisterAction.edit => 'Edit register',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: '$label?',
        message:
            '${register.name}: historical sales and shifts are preserved. '
            'An open shift must be closed before archiving or unassigning a device.',
        confirmLabel: label,
        destructive: action != RegisterAction.restore,
        icon: Icons.point_of_sale,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(manageRegisterUseCaseProvider)(
      session: ref.read(activeShiftSessionProvider),
      register: register,
      action: action,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.failureOrNull?.message ?? 'Register updated.'),
      ),
    );
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

  Future<void> _hardware(BuildContext context, Register register) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RegisterHardwareDialog(register: register),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register hardware updated.')),
      );
    }
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
    this.administrationOnly = false,
    required this.canManage,
    required this.canOpen,
    required this.onNewRegister,
    required this.onPolicy,
    required this.onOpenShift,
  });

  final bool canManage;
  final bool administrationOnly;
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
                administrationOnly
                    ? 'Registers & hardware'
                    : 'Register & shift',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                administrationOnly
                    ? 'Configure registers and hardware for the active branch.'
                    : 'Recoverable offline cash sessions with immutable drawer movements.',
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
        if (!administrationOnly)
          FilledButton.icon(
            onPressed: canOpen ? onOpenShift : null,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Open shift'),
          ),
      ],
    );
  }
}
