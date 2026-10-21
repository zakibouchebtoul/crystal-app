import 'package:crystal_app/data/addresses.dart';
import 'package:crystal_app/data/offers.dart';
import 'package:crystal_app/screens/home_screen.dart';
import 'package:crystal_app/screens/offers/offers_screen.dart';
import 'package:crystal_app/screens/popular/popular_screen.dart';
import 'package:crystal_app/screens/search/search_screen.dart';
import 'package:crystal_app/screens/service/company_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _wait(WidgetTester tester, [int steps = 20]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _home(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
  await _wait(tester, 30);
}

void main() {
  testWidgets('search finds packages and opens the company page', (
    tester,
  ) async {
    await _home(tester);
    await tester.tap(find.text('Search services, packages, companies'));
    await _wait(tester, 6);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Popular right now'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'interior');
    await _wait(tester, 6);
    expect(find.text('Packages'), findsOneWidget);
    await tester.tap(find.textContaining('Full interior', findRichText: true));
    await _wait(tester, 10);
    expect(find.byType(CompanyServiceScreen), findsOneWidget);
  });

  testWidgets('a banner opens offers; using one applies it', (tester) async {
    await _home(tester);
    appliedOffer.value = null;
    await tester.tap(find.byType(PageView));
    await _wait(tester, 10);
    expect(find.byType(OffersScreen), findsOneWidget);

    await tester.tap(find.text('Use offer').first);
    await _wait(tester, 14);
    expect(appliedOffer.value, isNotNull);
    // Lands on the service, with a toast saying the offer is on.
    expect(find.text('${appliedOffer.value!.code} is active'), findsOneWidget);
    await _wait(tester, 65);
    expect(find.textContaining('is active'), findsNothing);
    appliedOffer.value = null;
  });

  testWidgets('see all lists popular packages and filters them', (
    tester,
  ) async {
    await _home(tester);
    await tester.ensureVisible(find.text('See all'));
    await _wait(tester, 4);
    await tester.tap(find.text('See all'));
    await _wait(tester, 10);
    expect(find.byType(PopularScreen), findsOneWidget);
    expect(find.text('Full interior deep clean'), findsOneWidget);

    // The service chips scroll sideways.
    await tester.scrollUntilVisible(
      find.text('Carpet cleaning'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(PopularScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _wait(tester, 4);
    await tester.tap(find.text('Carpet cleaning'));
    await _wait(tester, 8);
    expect(find.text('Full interior deep clean'), findsNothing);
    expect(find.text('At-home shampoo'), findsOneWidget);
  });

  testWidgets('a new address is saved and selected', (tester) async {
    await _home(tester);
    final before = addressBook.all.length;
    await tester.tap(find.text(addressBook.selected.full));
    await _wait(tester, 8);
    expect(find.text('Where should we come?'), findsOneWidget);

    await tester.tap(find.text('Add a new address'));
    await _wait(tester, 8);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '66'); // zone
    await tester.enterText(fields.at(1), '901'); // street
    await tester.enterText(fields.at(2), '14'); // building
    await tester.enterText(fields.at(3), 'The Pearl');
    await _wait(tester, 4);
    await tester.tap(find.text('Save address'));
    await _wait(tester, 12);

    expect(addressBook.all.length, before + 1);
    expect(
      addressBook.selected.full,
      'Building 14, Street 901, Zone 66, The Pearl',
    );
    expect(find.text(addressBook.selected.full), findsOneWidget);
  });

  testWidgets('book again opens the same company and package', (tester) async {
    await _home(tester);
    await tester.ensureVisible(find.text('Book again').first);
    await _wait(tester, 4);
    // The header, then each card's button.
    expect(find.text('Book again'), findsAtLeastNWidgets(2));
    await tester.tap(find.text('Book again').at(1));
    await _wait(tester, 12);
    expect(find.byType(CompanyServiceScreen), findsOneWidget);
  });

  testWidgets('the avatar opens the profile tab', (tester) async {
    await _home(tester);
    await tester.tap(find.byType(CircleAvatar).first);
    await _wait(tester, 10);
    expect(find.text('General'), findsOneWidget);
  });
}
