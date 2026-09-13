import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/register_claim_action_grant.dart';

class ManagerReauthenticationDialog extends StatefulWidget {
  const ManagerReauthenticationDialog({super.key, required this.authorize});

  final Future<Result<RegisterClaimActionGrant, Failure>> Function({
    required String email,
    required String password,
  })
  authorize;

  @override
  State<ManagerReauthenticationDialog> createState() =>
      _ManagerReauthenticationDialogState();
}

class _ManagerReauthenticationDialogState
    extends State<ManagerReauthenticationDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manager authorization'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This signs the manager into a separate, temporary authentication context for this reassignment only.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _email,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Manager email'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _password,
              enabled: !_submitting,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Manager password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Authorize once'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter the manager email and password.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.authorize(
      email: _email.text,
      password: _password.text,
    );
    _password.clear();
    if (!mounted) return;
    result.fold(
      onSuccess: (grant) => Navigator.pop(context, grant),
      onFailure: (failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
    );
  }
}
