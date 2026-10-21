import 'package:crystal_app/data/messages.dart';
import 'package:crystal_app/screens/messages/chat_screen.dart';
import 'package:crystal_app/screens/messages/messages_effects.dart';
import 'package:crystal_app/screens/messages/messages_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _wait(WidgetTester tester, int steps) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('search filters, and a conversation opens its chat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessagesTab(onBack: () {})),
      ),
    );
    await _wait(tester, 10);
    expect(find.text('Sara M.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'support');
    await _wait(tester, 10);
    // Rows that don't match fold away (they stay in the tree, collapsed).
    bool visible(String name) => tester
        .widget<Collapse>(
          find.ancestor(of: find.text(name), matching: find.byType(Collapse)),
        )
        .visible;
    expect(visible('Sara M.'), isFalse);
    expect(visible('Crystal Support'), isTrue);

    await tester.tap(find.text('Crystal Support'));
    await _wait(tester, 10);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('View Booking'), findsOneWidget);
  });

  testWidgets('a quick reply is sent, seen and answered', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(conversation: sampleConversations.first)),
    );
    await _wait(tester, 5);

    await tester.tap(find.text('Great, thanks!'));
    await _wait(tester, 30);

    // Sent once (the chip is gone), seen, and a reply arrived.
    expect(find.text('Great, thanks!'), findsOneWidget);
    expect(find.text('Seen'), findsOneWidget);
    expect(find.textContaining("We'll take care of it"), findsOneWidget);
  });
}
