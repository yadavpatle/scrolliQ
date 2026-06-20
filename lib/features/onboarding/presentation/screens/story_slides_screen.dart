import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/mascot.dart';
import '../../data/onboarding_content.dart';
import '../../domain/onboarding_data.dart';

/// 9-slide story flow. Tapping "Continue" advances; on last slide calls
/// [onComplete] so the parent navigator can push the permission screen.
class StorySlides extends StatefulWidget {
  const StorySlides({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<StorySlides> createState() => _StorySlidesState();
}

class _StorySlidesState extends State<StorySlides> {
  final _ctrl = PageController();
  int _index = 0;

  void _next() {
    if (_index < kStorySlides.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == kStorySlides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: kStorySlides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideBody(slide: kStorySlides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: PrimaryButton(
                label: isLast ? "Let's Do This!" : 'Continue',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideBody extends StatelessWidget {
  const _SlideBody({required this.slide});
  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reel-count pill
          if (slide.reelCount != null) _ReelPill(count: slide.reelCount!, color: slide.reelCountColor!),
          if (slide.reelCount != null) const SizedBox(height: 24),

          // Headline
          Text(
            slide.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),

          if (slide.subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              slide.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 15),
            ),
          ],

          // Hero illustration: mascot (preferred) or emoji fallback.
          if (slide.mascotMood != null) ...[
            const SizedBox(height: 32),
            Mascot(mood: slide.mascotMood!, size: 148),
          ] else if (slide.emoji != null) ...[
            const SizedBox(height: 32),
            Text(slide.emoji!, style: const TextStyle(fontSize: 80)),
          ],

          // Chips (goals)
          if (slide.chips != null) ...[
            const SizedBox(height: 32),
            _ChipGrid(chips: slide.chips!),
          ],

          // Benefits
          if (slide.benefits != null) ...[
            const SizedBox(height: 32),
            ...slide.benefits!.map((b) => _BenefitRow(benefit: b)),
          ],
        ],
      ),
    );
  }
}

class _ReelPill extends StatelessWidget {
  const _ReelPill({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = count >= 500 ? '500+ reels' : '$count reels';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ChipGrid extends StatelessWidget {
  const _ChipGrid({required this.chips});
  final List<GoalChip> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(c.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});
  final Benefit benefit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(benefit.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Text(
            benefit.label,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
