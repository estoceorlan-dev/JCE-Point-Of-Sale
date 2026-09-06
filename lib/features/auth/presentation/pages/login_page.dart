import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/routing/app_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../../core/widgets/app_split_layout.dart';
import '../controllers/auth_controller.dart';
import '../theme/login_theme.dart';
import '../widgets/login_brand_header.dart';
import '../widgets/login_form.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _logoAsset = 'assets/images/jce_logo.jpg';
  static const _coverLogoAsset = 'assets/images/jce_cover_logo.jpg';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LoginTheme.from(Theme.of(context));
    final authState = ref.watch(authControllerProvider);
    final authError = authState.whenOrNull(
      error: (error, _) => error is Failure
          ? error.message
          : 'Your account access could not be resolved.',
    );
    final session = authState.asData?.value;
    final isLoadingWorkspace =
        _isSubmitting ||
        authState.isLoading ||
        (session != null && session.permissions.isNotEmpty);

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: AppSplitLayout(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LoginBrandHeader(logoAsset: _logoAsset),
                    const SizedBox(height: AppSpacing.xxl),
                    LoginForm(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      isSubmitting: isLoadingWorkspace,
                      obscurePassword: _obscurePassword,
                      errorMessage:
                          _errorMessage ??
                          authError ??
                          (session != null && session.permissions.isEmpty
                              ? 'This account currently has no permissions.'
                              : null),
                      onSubmit: _submit,
                      onTogglePasswordVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      onForgotPassword: _showForgotPasswordMessage,
                    ),
                  ],
                ),
                illustration: Image.asset(
                  _coverLogoAsset,
                  fit: BoxFit.contain,
                  semanticLabel:
                      'JCE Dry Goods Trading. From Our Store to Your Home.',
                ),
              ),
            ),
            if (isLoadingWorkspace)
              AppLoadingOverlay(
                message: _isSubmitting
                    ? 'Signing you in...'
                    : 'Loading your workspace...',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    TextInput.finishAutofillContext();
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    var shouldResetSubmitting = true;
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      switch (result) {
        case SuccessResult():
          context.go(AppRoute.dashboard.path);
          shouldResetSubmitting = false;
        case FailureResult(:final failure):
          setState(() => _errorMessage = failure.message);
      }
    } finally {
      if (mounted && shouldResetSubmitting) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordMessage() async {
    final result = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(_emailController.text);
    if (!mounted) {
      return;
    }
    switch (result) {
      case SuccessResult():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If the account exists, a password reset email has been sent.',
            ),
          ),
        );
      case FailureResult(:final failure):
        setState(() => _errorMessage = failure.message);
    }
  }
}
