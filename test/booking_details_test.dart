import 'package:crystal_app/data/bookings.dart';
import 'package:crystal_app/data/favourites.dart';
import 'package:crystal_app/screens/booking/booking_details_screen.dart';
import 'package:crystal_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _wait(WidgetTester tester, [int steps = 20]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('details opens from the upcoming card and can reschedule', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _wait(tester, 30);

    await tester.tap(find.text('Details').first);
    // The page plays its entrance before the actions rise in.
    await _wait(tester, 26);
    expect(find.byType(BookingDetailsScreen), findsOneWidget);
    expect(find.text('YOUR DAY'), findsOneWidget);

    final before = bookingStore.nextUpcoming(DateTime.now())!.start;
    await tester.tap(find.text('Reschedule'));
    await _wait(tester, 6);
    await tester.tap(find.text('10 AM'));
    await _wait(tester, 2);
    await tester.tap(find.textContaining('Move to'));
    await _wait(tester, 12);
    expect(find.text('Booking moved'), findsOneWidget);
    expect(
      bookingStore.all.any((b) => b.start.hour == 10 && b.start != before),
      isTrue,
    );
    await _wait(tester, 60);
  });

  testWidgets('cancelling removes the booking', (tester) async {
    _phone(tester);
    final b = bookingStore.nextUpcoming(DateTime.now())!;
    await tester.pumpWidget(
      MaterialApp(home: BookingDetailsScreen(booking: b)),
    );
    await _wait(tester, 26);
    await tester.tap(find.text('Cancel'));
    await _wait(tester, 6);
    await tester.tap(find.text('Cancel booking'));
    await _wait(tester, 10);
    expect(bookingStore.all.contains(b), isFalse);
    await _wait(tester, 60);
  });

  testWidgets('a heart saves a favourite and shows the row', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _wait(tester, 30);
    expect(find.text('Your favourites'), findsNothing);
    final heart = find.byIcon(Icons.favorite_border_rounded).first;
    await tester.ensureVisible(heart);
    await _wait(tester, 4);
    await tester.tap(heart);
    await _wait(tester, 10);
    expect(favourites.all, isNotEmpty);
    expect(find.text('Your favourites'), findsOneWidget);
  });

  testWidgets('rating the last service thanks and folds away', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _wait(tester, 30);
    final card = find.textContaining('How was');
    await tester.ensureVisible(card);
    await _wait(tester, 4);
    final rated = bookingStore.toRate(DateTime.now())!;
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    await _wait(tester, 6);
    expect(find.text('Thanks for rating!'), findsOneWidget);
    await _wait(tester, 20);
    expect(bookingStore.ratingOf(rated), 4);
  });
}
