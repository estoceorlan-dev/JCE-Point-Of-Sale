import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/register.dart';
import '../../domain/repositories/register_administration_repository.dart';
import '../controllers/shift_mutation_controller.dart';
import '../providers/register_administration_providers.dart';
import '../providers/shift_providers.dart';

class RegisterDialog extends ConsumerStatefulWidget {
  const RegisterDialog({super.key, this.register});
  final Register? register;

  @override
  ConsumerState<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends ConsumerState<RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _codeController = TextEditingController(
    text: widget.register?.code,
  );
  late final _nameController = TextEditingController(
    text: widget.register?.name,
  );
  bool _editing = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving =
        _editing || ref.watch(shiftMutationControllerProvider).isLoading;
    return AlertDialog(
      title: Text(widget.register == null ? 'New register' : 'Edit register'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Register code',
                  hintText: 'REG-01',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter at least two characters.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Register name'),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter a register name.'
                    : null,
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
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(
            saving
                ? 'Saving…'
                : widget.register == null
                ? 'Create register'
                : 'Save register',
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final register = widget.register;
    if (register != null) {
      setState(() => _editing = true);
      final result = await ref.read(manageRegisterUseCaseProvider)(
        session: ref.read(activeShiftSessionProvider),
        register: register,
        action: RegisterAction.edit,
        draft: RegisterDraft(
          code: _codeController.text,
          name: _nameController.text,
        ),
      );
      if (!mounted) return;
      setState(() => _editing = false);
      result.fold(
        onSuccess: (_) => Navigator.pop(context, true),
        onFailure: (failure) => setState(() => _error = failure.message),
      );
      return;
    }
    final result = await ref
        .read(shiftMutationControllerProvider.notifier)
        .createRegister(
          RegisterDraft(code: _codeController.text, name: _nameController.text),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => setState(() => _error = failure.message),
    );
  }
}
