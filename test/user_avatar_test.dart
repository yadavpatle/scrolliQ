import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrolliq/shared/widgets/user_avatar.dart';

/// Pulls the rendered initials out of a [UserAvatar] widget tree.
String _initialsFor(WidgetTester tester) {
  final textWidget = tester.widget<Text>(find.byType(Text));
  return textWidget.data ?? '';
}

Future<void> _pump(WidgetTester tester, {String? name, String? url}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: UserAvatar(name: name, url: url)),
    ),
  );
}

void main() {
  group('UserAvatar initials', () {
    testWidgets('shows ? when name is null', (tester) async {
      await _pump(tester);
      expect(_initialsFor(tester), '?');
    });

    testWidgets('shows ? when name is empty', (tester) async {
      await _pump(tester, name: '');
      expect(_initialsFor(tester), '?');
    });

    testWidgets('shows ? when name is whitespace only', (tester) async {
      await _pump(tester, name: '   ');
      expect(_initialsFor(tester), '?');
    });

    testWidgets('uses first letter of single-word name', (tester) async {
      await _pump(tester, name: 'alice');
      expect(_initialsFor(tester), 'A');
    });

    testWidgets('uses first two initials of two-word name', (tester) async {
      await _pump(tester, name: 'alice baker');
      expect(_initialsFor(tester), 'AB');
    });

    testWidgets('handles consecutive spaces without crashing', (tester) async {
      // Regression test: previously threw RangeError on `''[0]`.
      await _pump(tester, name: 'John  Doe');
      expect(_initialsFor(tester), 'JD');
    });

    testWidgets('handles tab/newline whitespace', (tester) async {
      await _pump(tester, name: 'John\t\tDoe');
      expect(_initialsFor(tester), 'JD');
    });

    testWidgets('limits to first two words even with three names',
        (tester) async {
      await _pump(tester, name: 'alice baker carter');
      expect(_initialsFor(tester), 'AB');
    });

    testWidgets('trims leading and trailing whitespace', (tester) async {
      await _pump(tester, name: '   alice baker  ');
      expect(_initialsFor(tester), 'AB');
    });
  });
}
