import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _State();
}

class _State extends ConsumerState<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool  _sent      = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_emailCtrl.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _sent = true);
    } else {
      final state = ref.read(authControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state is AsyncError
            ? state.error.toString()
            : 'Could not send reset email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _sent ? _buildSent() : _buildForm(auth.isLoading),
        ),
      ),
    );
  }

  Widget _buildForm(bool loading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter your email and we will send a link to reset your password.',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) => v == null || !v.contains('@')
                ? 'Enter a valid email'
                : null,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Send reset link',
            loading: loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 80, color: AppColors.success),
        const SizedBox(height: 16),
        const Text(
          'Check your email',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a reset link to ${_emailCtrl.text.trim()}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondaryDark),
        ),
      ],
    );
  }
}
