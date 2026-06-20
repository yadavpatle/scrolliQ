import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The single emotional state of the ScrollIQ mascot — "Cortex", a friendly
/// brain blob whose face changes with the user's focus.
///
/// The first five moods map 1:1 onto the Brain Score categories so the mascot
/// becomes a wordless summary of "how's my brain today?". The remaining moods
/// are general-purpose and reused for loading / empty / error / celebration
/// states across the app.
enum MascotMood {
  ecstatic, // 90-100  Focus Master
  happy, //    70-89   Healthy Focus
  neutral, //  50-69   Distracted
  sad, //      30-49   Doomscroller
  melting, //  0-29    Brain Melt
  thinking, // loading / fetching
  sleepy, //   idle / late-night / "nothing here"
  celebrating, // achievements, challenge complete
  dead, //     errors
}

/// One mascot, many emotions, reused everywhere.
///
/// ```dart
/// const Mascot(mood: MascotMood.happy, size: 80)
/// Mascot.forScore(72)                 // picks the mood from a Brain Score
/// const Mascot(mood: MascotMood.dead) // error state
/// ```
///
/// The widget is fully self-painted (no image/Lottie assets) so it scales
/// crisply at any size and re-themes automatically. It gently breathes and
/// blinks while mounted; pass `animate: false` for static contexts (tests,
/// dense lists).
class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    required this.mood,
    this.size = 96,
    this.color,
    this.animate = true,
  });

  /// Builds the mascot whose expression matches a 0–100 Brain Score, using the
  /// same thresholds as the dashboard's category logic.
  factory Mascot.forScore(
    int score, {
    Key? key,
    double size = 96,
    bool animate = true,
  }) {
    final MascotMood mood;
    if (score >= 90) {
      mood = MascotMood.ecstatic;
    } else if (score >= 70) {
      mood = MascotMood.happy;
    } else if (score >= 50) {
      mood = MascotMood.neutral;
    } else if (score >= 30) {
      mood = MascotMood.sad;
    } else {
      mood = MascotMood.melting;
    }
    return Mascot(key: key, mood: mood, size: size, animate: animate);
  }

  final MascotMood mood;
  final double size;

  /// Overrides the mood's default body colour.
  final Color? color;

  /// Idle breathing + blinking. Disable for static snapshots.
  final bool animate;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant Mascot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _painterFor(0);

    final child = SizedBox.square(
      dimension: widget.size,
      child: widget.animate
          ? AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                painter: _painterFor(_controller.value),
              ),
            )
          : CustomPaint(painter: painter),
    );

    return Semantics(
      label: '${_moodLabel(widget.mood)} mascot',
      child: child,
    );
  }

  _MascotPainter _painterFor(double t) => _MascotPainter(
        mood: widget.mood,
        color: widget.color ?? _defaultColor(widget.mood),
        t: t,
      );
}

String _moodLabel(MascotMood m) => switch (m) {
      MascotMood.ecstatic => 'Ecstatic',
      MascotMood.happy => 'Happy',
      MascotMood.neutral => 'Neutral',
      MascotMood.sad => 'Sad',
      MascotMood.melting => 'Melting',
      MascotMood.thinking => 'Thinking',
      MascotMood.sleepy => 'Sleepy',
      MascotMood.celebrating => 'Celebrating',
      MascotMood.dead => 'Dizzy',
    };

Color _defaultColor(MascotMood m) => switch (m) {
      MascotMood.ecstatic => AppColors.scoreFocusMaster,
      MascotMood.happy => AppColors.scoreHealthy,
      MascotMood.neutral => AppColors.scoreDistracted,
      MascotMood.sad => AppColors.scoreDoomscroller,
      MascotMood.melting => AppColors.scoreBrainMelt,
      MascotMood.thinking => AppColors.primary,
      MascotMood.sleepy => AppColors.info,
      MascotMood.celebrating => AppColors.accent,
      MascotMood.dead => AppColors.scoreBrainMelt,
    };

// =============================================================================
// Painter
// =============================================================================

class _MascotPainter extends CustomPainter {
  _MascotPainter({
    required this.mood,
    required this.color,
    required this.t,
  });

  final MascotMood mood;
  final Color color;

  /// Continuous 0..1 animation clock.
  final double t;

  static const Color _ink = AppColors.onPrimary; // dark eyes/mouth

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    const twoPi = math.pi * 2;

    // --- idle animation -----------------------------------------------------
    final breath = math.sin(t * twoPi); // -1..1
    final eyeOpen = _eyeOpen(t);
    final bob = breath * s * 0.012;

    canvas.save();
    canvas.translate(0, bob);
    // Breathing: scale very slightly around the centre.
    final scale = 1 + breath * 0.018;
    canvas.translate(s / 2, s / 2);
    canvas.scale(scale);
    canvas.translate(-s / 2, -s / 2);

    _drawShadow(canvas, s);
    _drawBody(canvas, s);
    _drawWrinkles(canvas, s);
    _drawFace(canvas, s, eyeOpen);
    _drawAccessories(canvas, s, breath);

    canvas.restore();
  }

  // --- blink clock ----------------------------------------------------------
  // Two quick blinks per 5s cycle. Returns 1 (open) .. 0 (closed).
  double _eyeOpen(double t) {
    if (mood == MascotMood.sleepy || mood == MascotMood.dead) return 1;
    double blinkAt(double centre) {
      final d = (t - centre).abs();
      const half = 0.035;
      if (d >= half) return 1;
      return Curves.easeInOut.transform(d / half);
    }

    return math.min(blinkAt(0.18), blinkAt(0.62));
  }

  // --- body -----------------------------------------------------------------
  void _drawShadow(Canvas canvas, double s) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.92),
        width: s * 0.62,
        height: s * 0.14,
      ),
      shadow,
    );
  }

  Path _squircle(Rect r, {double n = 4}) {
    final path = Path();
    const steps = 72;
    final a = r.width / 2, b = r.height / 2;
    final cx = r.center.dx, cy = r.center.dy;
    for (var i = 0; i <= steps; i++) {
      final theta = (i / steps) * math.pi * 2;
      final ct = math.cos(theta), st = math.sin(theta);
      final x = cx + a * _signedPow(ct, 2 / n);
      final y = cy + b * _signedPow(st, 2 / n);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  double _signedPow(double base, double exp) =>
      (base < 0 ? -1 : 1) * math.pow(base.abs(), exp).toDouble();

  void _drawBody(Canvas canvas, double s) {
    final rect = Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.5),
      width: s * 0.84,
      height: s * 0.82,
    );
    final body = _squircle(rect, n: 3.4);

    // Glow halo.
    canvas.drawCircle(
      Offset(s * 0.5, s * 0.5),
      s * 0.46,
      Paint()
        ..color = color.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Gradient fill (lighter top → richer bottom).
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lighten(color, 0.18), _darken(color, 0.12)],
      ).createShader(rect);
    canvas.drawPath(body, fill);

    // Soft top highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.42, s * 0.30),
        width: s * 0.40,
        height: s * 0.24,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Definition outline.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = _darken(color, 0.28).withValues(alpha: 0.6),
    );
  }

  /// Faint brain folds so the blob reads as a brain at any size.
  void _drawWrinkles(Canvas canvas, double s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.018
      ..color = _darken(color, 0.22).withValues(alpha: 0.35);

    Path arc(double cx, double cy, double w, double h, double start, double sweep) =>
        Path()
          ..addArc(
            Rect.fromCenter(
                center: Offset(cx, cy), width: w, height: h),
            start,
            sweep,
          );

    canvas.drawPath(arc(s * 0.35, s * 0.24, s * 0.20, s * 0.16, math.pi * 0.9, math.pi * 1.1), p);
    canvas.drawPath(arc(s * 0.62, s * 0.23, s * 0.20, s * 0.16, math.pi * 0.9, math.pi * 1.1), p);
    canvas.drawPath(arc(s * 0.5, s * 0.34, s * 0.16, s * 0.12, math.pi * 0.95, math.pi * 1.1), p);
  }

  // --- face -----------------------------------------------------------------
  void _drawFace(Canvas canvas, double s, double eyeOpen) {
    final eyeY = s * 0.52;
    final lx = s * 0.38, rx = s * 0.62;

    switch (mood) {
      case MascotMood.ecstatic:
      case MascotMood.celebrating:
        _happyArcEye(canvas, Offset(lx, eyeY), s);
        _happyArcEye(canvas, Offset(rx, eyeY), s);
      case MascotMood.happy:
        _roundEye(canvas, Offset(lx, eyeY), s, eyeOpen);
        _roundEye(canvas, Offset(rx, eyeY), s, eyeOpen);
      case MascotMood.sleepy:
        _closedEye(canvas, Offset(lx, eyeY), s);
        _closedEye(canvas, Offset(rx, eyeY), s);
      case MascotMood.dead:
        _xEye(canvas, Offset(lx, eyeY), s);
        _xEye(canvas, Offset(rx, eyeY), s);
      case MascotMood.melting:
        _roundEye(canvas, Offset(lx, eyeY), s, eyeOpen * 0.5);
        _roundEye(canvas, Offset(rx, eyeY), s, eyeOpen * 0.5);
        _worriedBrows(canvas, s, lx, rx, eyeY);
      case MascotMood.sad:
        _roundEye(canvas, Offset(lx, eyeY), s, eyeOpen);
        _roundEye(canvas, Offset(rx, eyeY), s, eyeOpen);
        _worriedBrows(canvas, s, lx, rx, eyeY);
      case MascotMood.neutral:
      case MascotMood.thinking:
        final lookUp = mood == MascotMood.thinking;
        _roundEye(canvas, Offset(lx, eyeY), s, eyeOpen, lookUp: lookUp);
        _roundEye(canvas, Offset(rx, eyeY), s, eyeOpen, lookUp: lookUp);
    }

    _drawMouth(canvas, s);
    _drawBlush(canvas, s);
  }

  void _roundEye(Canvas canvas, Offset c, double s, double open,
      {bool lookUp = false}) {
    final r = s * 0.095;
    final ry = (r * open).clamp(0.0, r);
    final eye = Paint()..color = _ink;

    if (open < 0.18) {
      // Blink → soft curved lash line.
      final path = Path()
        ..moveTo(c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy + r * 0.45, c.dx + r, c.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _ink
          ..strokeWidth = r * 0.6
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2, height: ry * 2),
      eye,
    );
    // Big glossy catch-light + small secondary sparkle = extra cute.
    final hl = c.translate(-r * 0.30, -ry * 0.40 + (lookUp ? -r * 0.2 : 0));
    canvas.drawCircle(hl, r * 0.42, Paint()..color = Colors.white);
    canvas.drawCircle(
      c.translate(r * 0.34, ry * 0.30),
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _happyArcEye(Canvas canvas, Offset c, double s) {
    final w = s * 0.18, h = s * 0.18;
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, h * 0.18), width: w, height: h),
      math.pi, // start left
      math.pi, // upper half → bulges upward (^_^)
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.036
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
  }

  void _closedEye(Canvas canvas, Offset c, double s) {
    final w = s * 0.14;
    final path = Path()
      ..moveTo(c.dx - w / 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + s * 0.04, c.dx + w / 2, c.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.026
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
  }

  void _xEye(Canvas canvas, Offset c, double s) {
    final r = s * 0.06;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.028
      ..strokeCap = StrokeCap.round
      ..color = _ink;
    canvas.drawLine(c.translate(-r, -r), c.translate(r, r), p);
    canvas.drawLine(c.translate(r, -r), c.translate(-r, r), p);
  }

  void _worriedBrows(
      Canvas canvas, double s, double lx, double rx, double eyeY) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round
      ..color = _ink;
    final bw = s * 0.07, gap = s * 0.14, lift = s * 0.05;
    // Inner ends raised (toward centre) → classic worried look.
    canvas.drawLine(
        Offset(lx - bw, eyeY - gap + lift), Offset(lx + bw, eyeY - gap), p);
    canvas.drawLine(
        Offset(rx + bw, eyeY - gap + lift), Offset(rx - bw, eyeY - gap), p);
  }

  void _drawMouth(Canvas canvas, double s) {
    final cx = s * 0.5, my = s * 0.72;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.030
      ..strokeCap = StrokeCap.round
      ..color = _ink;
    final fill = Paint()..color = _ink;

    switch (mood) {
      case MascotMood.ecstatic:
      case MascotMood.celebrating:
        // Big open grin with a tongue.
        final w = s * 0.14;
        final path = Path()
          ..moveTo(cx - w, my)
          ..quadraticBezierTo(cx, my + s * 0.16, cx + w, my)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawCircle(
          Offset(cx, my + s * 0.075),
          s * 0.04,
          Paint()..color = AppColors.secondary,
        );
      case MascotMood.happy:
        final w = s * 0.085;
        canvas.drawPath(
          Path()
            ..moveTo(cx - w, my)
            ..quadraticBezierTo(cx, my + s * 0.07, cx + w, my),
          stroke,
        );
      case MascotMood.neutral:
        canvas.drawLine(
            Offset(cx - s * 0.08, my), Offset(cx + s * 0.08, my), stroke);
      case MascotMood.thinking:
        // Small off-centre line — pensive.
        canvas.drawLine(Offset(cx - s * 0.02, my),
            Offset(cx + s * 0.09, my - s * 0.01), stroke);
      case MascotMood.sad:
        final w = s * 0.10;
        canvas.drawPath(
          Path()
            ..moveTo(cx - w, my + s * 0.04)
            ..quadraticBezierTo(cx, my - s * 0.05, cx + w, my + s * 0.04),
          stroke,
        );
      case MascotMood.melting:
        // Drooping open ooze.
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, my + s * 0.03),
              width: s * 0.13,
              height: s * 0.10),
          fill,
        );
      case MascotMood.sleepy:
        canvas.drawCircle(
          Offset(cx, my),
          s * 0.035,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.022
            ..color = _ink,
        );
      case MascotMood.dead:
        canvas.drawPath(
          Path()
            ..moveTo(cx - s * 0.08, my)
            ..quadraticBezierTo(cx - s * 0.04, my - s * 0.04, cx, my)
            ..quadraticBezierTo(cx + s * 0.04, my + s * 0.04, cx + s * 0.08, my),
          stroke,
        );
    }
  }

  void _drawBlush(Canvas canvas, double s) {
    // Rosy cheeks make almost every mood cuter — skip only for the lifeless
    // "dead" face.
    if (mood == MascotMood.dead) return;
    final strong = mood == MascotMood.happy ||
        mood == MascotMood.ecstatic ||
        mood == MascotMood.celebrating;
    final blush = Paint()
      ..color = AppColors.secondary.withValues(alpha: strong ? 0.38 : 0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final cy = s * 0.64;
    final w = s * 0.12, h = s * 0.075;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.24, cy), width: w, height: h),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.76, cy), width: w, height: h),
      blush,
    );
  }

  // --- accessories ----------------------------------------------------------
  void _drawAccessories(Canvas canvas, double s, double breath) {
    switch (mood) {
      case MascotMood.ecstatic:
      case MascotMood.celebrating:
        _sparkles(canvas, s, breath);
      case MascotMood.sad:
        _sweatDrop(canvas, s);
      case MascotMood.melting:
        _drips(canvas, s);
      case MascotMood.sleepy:
        _zzz(canvas, s, breath);
      case MascotMood.thinking:
        _thinkingDots(canvas, s);
      default:
        break;
    }
  }

  void _sparkles(Canvas canvas, double s, double breath) {
    final twinkle = 0.7 + 0.3 * ((breath + 1) / 2);
    final spots = [
      Offset(s * 0.16, s * 0.20),
      Offset(s * 0.86, s * 0.26),
      Offset(s * 0.80, s * 0.70),
    ];
    final sizes = [s * 0.055, s * 0.04, s * 0.035];
    for (var i = 0; i < spots.length; i++) {
      _star(canvas, spots[i], sizes[i] * twinkle, AppColors.accent);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final ang = (math.pi / 4) * i;
      final rr = i.isEven ? r : r * 0.4;
      final p = c.translate(rr * math.cos(ang), rr * math.sin(ang));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _sweatDrop(Canvas canvas, double s) {
    final c = Offset(s * 0.80, s * 0.40);
    final r = s * 0.05;
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 1.6)
      ..quadraticBezierTo(c.dx + r, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r, c.dy, c.dx, c.dy - r * 1.6)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.info);
    canvas.drawCircle(
      c.translate(-r * 0.3, -r * 0.2),
      r * 0.25,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _drips(Canvas canvas, double s) {
    final fill = Paint()..color = _darken(color, 0.06);
    for (final d in [
      [s * 0.30, s * 0.82, s * 0.05],
      [s * 0.5, s * 0.86, s * 0.06],
      [s * 0.70, s * 0.83, s * 0.045],
    ]) {
      canvas.drawCircle(Offset(d[0], d[1]), d[2], fill);
    }
  }

  void _zzz(Canvas canvas, double s, double breath) {
    final rise = breath * s * 0.02;
    _drawText(canvas, 'z', Offset(s * 0.74, s * 0.30 + rise), s * 0.12);
    _drawText(canvas, 'z', Offset(s * 0.84, s * 0.20 + rise), s * 0.16);
    _drawText(canvas, 'Z', Offset(s * 0.92, s * 0.08 + rise), s * 0.22);
  }

  void _thinkingDots(Canvas canvas, double s) {
    final p = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final phase = ((t * 3) - i * 0.33) % 1.0;
      final a = 0.3 + 0.7 * (math.sin(phase * math.pi).clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(s * (0.76 + i * 0.08), s * 0.22),
        s * 0.022,
        p..color = color.withValues(alpha: a),
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset c, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  // --- colour helpers -------------------------------------------------------
  Color _lighten(Color c, double amt) => Color.lerp(c, Colors.white, amt)!;
  Color _darken(Color c, double amt) => Color.lerp(c, Colors.black, amt)!;

  @override
  bool shouldRepaint(covariant _MascotPainter old) =>
      old.t != t || old.mood != mood || old.color != color;
}
