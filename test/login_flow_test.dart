import 'package:crystal_app/screens/account_type_screen.dart';
import 'package:crystal_app/screens/home_screen.dart';
import 'package:crystal_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advances past the mock backend delay and page transitions. The screens
/// have looping background animations, so pumpAndSettle can't be used.
Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _submit(WidgetTester tester, String number) async {
  // A phone-sized screen (402 × 874), like the mockups.
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  await tester.enterText(find.byType(TextField), number);
  await tester.tap(find.text('Continue'));
  await _wait(tester);
}

void main() {
  testWidgets('an invalid number shows an error and stays on login', (
    tester,
  ) async {
    await _submit(tester, '123');
    expect(find.textContaining('valid Qatar mobile number'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a registered number goes straight home', (tester) async {
    await _submit(tester, '55555555');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AccountTypeScreen), findsNothing);
  });

  testWidgets('a new number picks an account type, then goes home', (
    tester,
  ) async {
    await _submit(tester, '33334444');
    expect(find.byType(AccountTypeScreen), findsOneWidget);

    await tester.tap(find.text('Personal account'));
    await tester.tap(find.text('Continue'));
    await _wait(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
