import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/offline_pin_controller.dart';

class OfflinePinPanel extends ConsumerStatefulWidget {
  const OfflinePinPanel({super.key, this.enroll = false});
  final bool enroll;
  @override
  ConsumerState<OfflinePinPanel> createState() => _OfflinePinPanelState();
}

class _OfflinePinPanelState extends ConsumerState<OfflinePinPanel> {
  final _pin = TextEditingController();
  final _password = TextEditingController();
  String? _account;
  String? _message;
  bool _busy = false;
  @override
  void dispose() {
    _pin.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(enrolledCashiersProvider);
    return ExpansionTile(
      title: Text(
        widget.enroll
            ? 'Enroll offline cashier PIN'
            : 'Sign in with an offline PIN',
      ),
      childrenPadding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          widget.enroll
              ? 'Use your account password to enroll a 6–12 digit PIN on this device. Enrollment expires and must be renewed online.'
              : 'Previously enrolled cashiers can use cached products while the API is unavailable.',
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.enroll)
          TextField(
            controller: _password,
            obscureText: true,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Account password'),
          )
        else
          accounts.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Unable to read enrolled accounts.'),
            data: (values) => values.isEmpty
                ? const Text(
                    'No cashier is enrolled on this device. Sign in online first.',
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _account,
                    decoration: const InputDecoration(labelText: 'Cashier'),
                    items: [
                      for (final value in values)
                        DropdownMenuItem(
                          value: '${value.identityId}:${value.branchId}',
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _account = value),
                  ),
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _pin,
          obscureText: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          maxLength: 12,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        if (_message != null) Text(_message!, semanticsLabel: _message),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? 'Please wait…'
                : widget.enroll
                ? 'Enroll this device'
                : 'Sign in offline',
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!RegExp(r'^\d{6,12}$').hasMatch(_pin.text) ||
        !widget.enroll && _account == null) {
      setState(() => _message = 'Choose a cashier and enter a 6–12 digit PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(offlinePinControllerProvider)
          .submit(
            identityId: _account?.split(':').first,
            branchId: _account?.split(':').last,
            password: widget.enroll ? _password.text : null,
            pin: _pin.text,
          );
      if (mounted) {
        setState(
          () => _message =
              result.failureOrNull?.message ??
              'Offline PIN enrolled on this device.',
        );
      }
    } finally {
      _pin.clear();
      _password.clear();
      if (mounted) setState(() => _busy = false);
    }
  }
}
