import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrolliq/shared/widgets/mascot.dart';

Future<void> _pump(WidgetTester tester, Widget mascot) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: mascot))),
  );
}

void main() {
  group('Mascot', () {
    testWidgets('renders every mood without throwing', (tester) async {
      for (final mood in MascotMood.values) {
        await _pump(tester, Mascot(mood: mood, animate: false));
        expect(find.byType(Mascot), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('forScore maps Brain Score ranges to the right mood',
        (tester) async {
      const cases = <int, MascotMood>{
        95: MascotMood.ecstatic,
        90: MascotMood.ecstatic,
        80: MascotMood.happy,
        70: MascotMood.happy,
        60: MascotMood.neutral,
        50: MascotMood.neutral,
        40: MascotMood.sad,
        30: MascotMood.sad,
        10: MascotMood.melting,
        0: MascotMood.melting,
      };
      cases.forEach((score, expected) {
        final mascot = Mascot.forScore(score, animate: false);
        expect(mascot.mood, expected, reason: 'score $score');
      });
    });

    testWidgets('honours a custom colour override', (tester) async {
      await _pump(
        tester,
        const Mascot(
          mood: MascotMood.happy,
          color: Color(0xFF123456),
          animate: false,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('animated mascot mounts and disposes cleanly', (tester) async {
      await _pump(tester, const Mascot(mood: MascotMood.thinking));
      await tester.pump(const Duration(milliseconds: 500));
      // Replace with an empty tree to trigger dispose of the controller.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });
}
