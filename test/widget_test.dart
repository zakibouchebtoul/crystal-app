// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:crystal_app/main.dart';

void main() {
  testWidgets('splash → onboarding → sign-in → home', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Let the splash animation finish and fade into the onboarding.
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(seconds: 1));

    // Skip to the last slide and start.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // The label shares the knob with a (hidden) arrow, which takes the hit.
    await tester.tap(find.text('Start Now'), warnIfMissed: false);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Sign-in screen: skip as a guest.
    await tester.tap(find.text('Skip'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Home has looping animations (weather, live status), so step time
    // instead of waiting for it to settle.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Home tab is showing.
    expect(find.text('Most Booked Services'), findsOneWidget);
    expect(find.text('Car wash'), findsOneWidget);

    // The bottom bar switches tabs.
    await tester.tap(find.text('Profile'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('General'), findsOneWidget);
    expect(find.text('bomohamed@test.com'), findsOneWidget);
  });
}
