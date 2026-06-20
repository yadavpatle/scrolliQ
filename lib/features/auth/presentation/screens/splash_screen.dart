import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/mascot.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decideRoute());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _decideRoute() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final onboardingDone =
        prefs.getBool(AppConstants.prefOnboardingDone) ?? false;

    if (!onboardingDone) {
      context.go('/onboarding');
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (!mounted) return;
    context.go(session == null ? '/login' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle accent glow in the top-right corner.
            Positioned(
              top: -120,
              right: -120,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BrandMark(),
                  SizedBox(height: 28),
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    AppConstants.tagline,
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Center(child: _DotsLoader(controller: _ctrl)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft outer halo.
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.32),
                  Colors.transparent,
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
          // The ScrollIQ mascot is the logo.
          const Mascot(mood: MascotMood.ecstatic, size: 108),
        ],
      ),
    );
  }
}

class _DotsLoader extends StatelessWidget {
  const _DotsLoader({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final t = ((controller.value - i * 0.18) % 1.0).clamp(0.0, 1.0);
            final scale = 0.6 + 0.6 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
