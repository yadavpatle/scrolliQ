import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../referral/providers.dart';
import '../../providers.dart';

/// Combined invite-code panel shown at the top of the Friends → Find tab.
///
/// Two stacked sections (vertical layout — intentionally avoids placing a
/// `TextField` and a button in the same `Row`, which renders blank inside a
/// `SliverToBoxAdapter` on this app's layout):
///   • **Your code** — the signed-in user's referral code + a full-width Copy
///     button that copies it to the clipboard.
///   • **Got a friend's code?** — a paste field + full-width Redeem button that
///     calls the `redeem_referral` RPC (same backend as the deep-link flow),
///     creating a pending friend request from whoever owns the entered code.
class InviteCodeCard extends ConsumerStatefulWidget {
  const InviteCodeCard({super.key});

  @override
  ConsumerState<InviteCodeCard> createState() => _InviteCodeCardState();
}

class _InviteCodeCardState extends ConsumerState<InviteCodeCard> {
  final TextEditingController _controller = TextEditingController();
  bool _redeeming = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyOwnCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$code" to clipboard.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _redeem() async {
    final raw = _controller.text.trim().toUpperCase();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a friend's invite code first.")),
      );
      return;
    }

    setState(() => _redeeming = true);
    try {
      await ref.read(referralRepositoryProvider).redeem(raw);
      if (!mounted) return;
      _controller.clear();
      // Refresh request lists so the new pending request shows up.
      ref.invalidate(outgoingRequestsProvider);
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(friendsListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code redeemed — friend request sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not redeem code: $e')),
      );
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeAsync = ref.watch(myReferralCodeProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- YOUR CODE ----------
          const _Label('YOUR INVITE CODE'),
          const SizedBox(height: 8),
          codeAsync.when(
            loading: () => _codeBox(text: 'Loading…'),
            error: (_, __) => _codeBox(text: 'Sign in to see your code'),
            data: (code) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _codeBox(text: code),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyOwnCode(code),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderDark),
          const SizedBox(height: 16),

          // ---------- REDEEM ----------
          const _Label("GOT A FRIEND'S CODE?"),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                LengthLimitingTextInputFormatter(32),
                _UpperCaseFormatter(),
              ],
              decoration: const InputDecoration(
                hintText: 'Enter or paste code',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _redeem(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _redeeming ? null : _redeem,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: _redeeming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text('Redeem code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBox({required String text}) {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.textPrimaryDark,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: AppColors.textSecondaryDark,
      ),
    );
  }
}

/// Forces all input to upper-case so codes match the canonical format used by
/// `ReferralRepository.parseCode`.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(
      text: upper,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
