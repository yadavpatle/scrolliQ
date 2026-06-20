import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/mascot.dart';

/// "Open YouTube to see ScrollIQ in action" — launches YouTube so user sees
/// the HUD bubble counting live. [onComplete] fires to finish onboarding.
class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;

  Future<void> _openYouTube() async {
    // Try deep-linking to YouTube Shorts feed; falls back to main.
    final uri = Uri.parse('https://www.youtube.com/shorts');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(text: 'Open '),
                    TextSpan(
                      text: 'YouTube',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    TextSpan(text: ' to see\nScrollIQ in action'),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Mascot(mood: MascotMood.happy, size: 92),
              const SizedBox(height: 24),
              // YouTube logo stand-in
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.red, size: 36),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _openYouTube();
                    onComplete();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Open YouTube', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
