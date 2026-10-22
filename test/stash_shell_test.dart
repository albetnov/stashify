// The shell: the mutation, the write and what the user is told about it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/services/stash_service.dart';
import 'package:stashify/widgets/stash_shell.dart';

import 'fixtures/feed_fixture.dart';

Widget _host(StashService service) {
  return MaterialApp(
    home: Scaffold(body: StashShell(service: service)),
  );
}

void main() {
  testWidgets('A stashed feed is saved and the user is told', (
    WidgetTester tester,
  ) async {
    final service = serviceServing(feedXml);
    await tester.pumpWidget(_host(service));

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/feed.xml',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pumpAndSettle();

    expect(await service.loadLibrary(), hasLength(1));
    expect((await service.loadLibrary()).single.title, 'Stashify Weekly');
    expect(find.text('Saved for offline reading.'), findsOneWidget);
  });

  testWidgets('A failed link is reported and nothing is stashed', (
    WidgetTester tester,
  ) async {
    final service = serviceServing('Not found', status: 404);
    await tester.pumpWidget(_host(service));

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/feed.xml',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pumpAndSettle();

    expect(await service.loadLibrary(), isEmpty);
    expect(find.textContaining('404'), findsOneWidget);
    expect(find.text('Saved for offline reading.'), findsNothing);
  });

  testWidgets('A failed link stays in the field, ready to be fixed', (
    WidgetTester tester,
  ) async {
    final service = serviceServing(pageHtml);
    await tester.pumpWidget(_host(service));

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/feed.xml',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'https://example.com/feed.xml');
  });
}
