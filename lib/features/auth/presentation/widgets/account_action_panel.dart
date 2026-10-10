import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/account_action_controller.dart';

class AccountActionPanel extends ConsumerStatefulWidget {
  const AccountActionPanel({super.key});
  @override
  ConsumerState<AccountActionPanel> createState() => _AccountActionPanelState();
}

class _AccountActionPanelState extends ConsumerState<AccountActionPanel> {
  final _form = GlobalKey<FormState>();
  final _token = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  var _recovery = false, _busy = false;
  String? _message;
  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Activate account or recover password'),
    children: [
      Form(
        key: _form,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              DropdownButtonFormField<bool>(
                initialValue: _recovery,
                items: const [
                  DropdownMenuItem(
                    value: false,
                    child: Text('Activate invited account'),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: Text('Recover password'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _recovery = value!),
                decoration: const InputDecoration(labelText: 'Account action'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _token,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'One-time token from your administrator',
                ),
                validator: (value) =>
                    RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter the issued token.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'New password (12-128 characters)',
                ),
                validator: (value) =>
                    (value?.length ?? 0) >= 12 && (value?.length ?? 0) <= 128
                    ? null
                    : 'Use 12-128 characters.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirmation,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) =>
                    value == _password.text ? null : 'Passwords must match.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (_message != null) Text(_message!),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Saving...' : 'Set password'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await ref
        .read(accountActionServiceProvider)
        .complete(
          token: _token.text.trim(),
          password: _password.text,
          recovery: _recovery,
        );
    _token.clear();
    _password.clear();
    _confirmation.clear();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.isSuccess
          ? 'Password saved. Sign in with your email and new password.'
          : result.failureOrNull!.message;
    });
  }
}
