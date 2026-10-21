import 'package:crystal_app/data/service_catalog.dart';
import 'package:crystal_app/screens/home_screen.dart';
import 'package:crystal_app/screens/service/companies_screen.dart';
import 'package:crystal_app/screens/service/company_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _wait(WidgetTester tester, int steps) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('pick a company, options and a time, then book', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(CompaniesScreen.route(serviceCatalog['Car wash']!)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _wait(tester, 15);

    // Every car wash company is listed; pick Qatar wash.
    expect(find.text('The most relevant'), findsOneWidget);
    expect(find.text('Shine Auto Spa'), findsWidgets);
    await tester.tap(find.text('Qatar wash').first);
    await _wait(tester, 15);
    expect(find.byType(CompanyServiceScreen), findsOneWidget);

    // Most booked package is preselected: 79 QAR. SUV adds 15.
    expect(find.text('Pick a time'), findsOneWidget);
    // Bring options to the middle of the screen (clear of the bars).
    await Scrollable.ensureVisible(
      tester.element(find.text('SUV', skipOffstage: false)),
      alignment: 0.5,
    );
    await _wait(tester, 4);
    await tester.tap(find.text('SUV'));
    await _wait(tester, 6);

    await Scrollable.ensureVisible(
      tester.element(find.text('10 AM', skipOffstage: false)),
      alignment: 0.5,
    );
    await _wait(tester, 4);
    await tester.tap(find.text('10 AM'));
    await _wait(tester, 6);
    expect(find.text('Book · 94 QAR'), findsOneWidget);

    await tester.tap(find.text('Book · 94 QAR'));
    await _wait(tester, 6);
    expect(find.text('Review your booking'), findsOneWidget);

    await tester.tap(find.text('Confirm booking'));
    await _wait(tester, 15);
    expect(find.text('How would you like to pay?'), findsOneWidget);
    expect(find.text('Pay 94 QAR'), findsOneWidget);

    await tester.tap(find.text('Cash on delivery'));
    await _wait(tester, 4);
    await tester.tap(find.text('Confirm cash payment'));
    await _wait(tester, 15);
    expect(find.text('Booking confirmed'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await _wait(tester, 6);
    expect(find.byType(CompanyServiceScreen), findsNothing);
  });

  testWidgets('a most booked card opens the top company, ready to compare', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _wait(tester, 30);

    // Cheapest company's price for the package.
    expect(find.text('from 67 QAR'), findsOneWidget);
    // Also under "Book again" when that booking is done, so take the
    // Most Booked card (the last one on the page).
    await tester.ensureVisible(find.text('Full interior deep clean').last);
    await _wait(tester, 4);
    await tester.tap(find.text('Full interior deep clean').last);
    await _wait(tester, 20);

    // Top rated company, with the package preselected.
    expect(find.byType(CompanyServiceScreen), findsOneWidget);
    expect(find.text('Qatar wash'), findsWidgets);
    expect(find.text('Book · 79 QAR'), findsNothing);
    await Scrollable.ensureVisible(
      tester.element(
        find.text('Also at 2 other companies', skipOffstage: false),
      ),
      alignment: 0.5,
    );
    await _wait(tester, 4);
    // Doha Car Care does it for 67 instead of 79.
    expect(
      find.textContaining('save 12 QAR', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Compare'));
    await _wait(tester, 10);
    expect(find.text('Compare companies'), findsOneWidget);
    expect(find.text('Best price'), findsOneWidget);
    expect(find.text('Viewing'), findsOneWidget);

    await tester.tap(find.text('Doha Car Care').last);
    await _wait(tester, 20);
    expect(find.text('Compare companies'), findsNothing);
    expect(find.byType(CompanyServiceScreen), findsOneWidget);
    expect(find.text('Doha Car Care', skipOffstage: false), findsWidgets);
  });
}
