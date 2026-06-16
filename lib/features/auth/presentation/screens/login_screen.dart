import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).signIn(
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      _showError();
    }
  }

  Future<void> _google() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      _showError();
    }
  }

  void _showError() {
    final state = ref.read(authControllerProvider);
    final msg = state is AsyncError
        ? state.error.toString()
        : 'Something went wrong.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth.isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Soft accent glow behind the hero.
          Positioned(
            top: -120,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const _BrandRow(),
                    const SizedBox(height: 36),
                    const Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimaryDark,
                        ),
                        children: [
                          TextSpan(text: 'Welcome\n'),
                          TextSpan(
                            text: 'back.',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Log in to continue your focus streak.',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Min 6 characters'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondaryDark,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Log in',
                      onPressed: _submit,
                      loading: loading,
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.borderDark)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: AppColors.textTertiaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.borderDark)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SecondaryButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: loading ? null : _google,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ",
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 14,
                            )),
                        GestureDetector(
                          onTap: () => context.go('/signup'),
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: const Icon(Icons.bolt_rounded, color: AppColors.onPrimary, size: 22),
        ),
        const SizedBox(width: 10),
        const Text(
          'ScrollIQ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textPrimaryDark,
          ),
        ),
      ],
    );
  }
}
