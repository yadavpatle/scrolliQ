import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../providers.dart';

/// Bottom sheet for joining a group via invite code.
class JoinGroupSheet extends ConsumerStatefulWidget {
  const JoinGroupSheet({super.key});

  @override
  ConsumerState<JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<JoinGroupSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(groupsRepositoryProvider).joinByCode(code);
      ref.invalidate(myGroupsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined group successfully! 🎉'),
          ),
        );
      }
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.contains('Invalid invite code')
            ? 'Invalid invite code. Please check and try again.'
            : msg.contains('Group is full')
                ? 'This group is full.'
                : 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Join a Group',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter the 6-character invite code shared by the group creator.',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Code input
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: AppText.mono(
              size: 24,
              color: AppColors.primary,
              weight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: AppText.mono(
                size: 24,
                color: AppColors.textTertiaryDark,
                weight: FontWeight.w400,
              ),
              counterText: '',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Join Group',
              icon: Icons.group_add_rounded,
              loading: _loading,
              onPressed:
                  _controller.text.trim().isEmpty ? null : _join,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
