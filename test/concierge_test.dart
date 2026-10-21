import 'package:crystal_app/screens/calendar/calendar_tab.dart';
import 'package:crystal_app/screens/concierge/concierge_screen.dart';
import 'package:crystal_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page has looping animations (orb, mic), so pumpAndSettle can't be
/// used; advance time in steps instead.
Future<void> _wait(WidgetTester tester, [int steps = 30]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a quick suggestion gets weather and bookable services', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(const MaterialApp(home: ConciergeScreen()));
    await _wait(tester, 15);

    await tester.tap(find.text('Wash my car today'));
    // Replies stream in word by word, so give them time to finish.
    await _wait(tester, 70);

    expect(find.text('DOHA · NEXT 3 DAYS'), findsOneWidget);
    expect(find.textContaining('Thursday is clear'), findsOneWidget);
    expect(find.text('Book Now'), findsWidgets);
  });

  testWidgets('listening transcribes the request and sends it', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(const MaterialApp(home: ConciergeScreen()));
    await _wait(tester, 15);

    await tester.tap(
      find.image(const AssetImage('assets/images/concierge/mic_orb.png')),
    );
    await tester.pump();
    expect(find.text('Listening...'), findsOneWidget);

    await _wait(tester, 70);
    expect(find.textContaining('Skip the car wash today'), findsOneWidget);
    expect(find.textContaining('carpet team', findRichText: true), findsOne);
  });

  testWidgets('the calendar button returns to the calendar tab', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _wait(tester, 25);

    await tester.tap(find.text('AI Concierge'));
    await _wait(tester, 10);
    expect(find.byType(ConciergeScreen), findsOneWidget);

    // Header: back, menu, calendar — the calendar is the last round button.
    await tester.tap(find.byType(InkWell).at(2));
    await _wait(tester, 10);
    expect(find.byType(ConciergeScreen), findsNothing);
    expect(tester.widget<CalendarTab>(find.byType(CalendarTab)).active, isTrue);
  });
}
