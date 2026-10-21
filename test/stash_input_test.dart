// The input card on its own: the form, the validation and the pending state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart';

import 'package:stashify/widgets/stash_input.dart';

Widget _host({
  required Future<bool> Function(String url) onSubmit,
  required Signal<bool> pending,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StashInput(onSubmit: onSubmit, isPending: pending),
    ),
  );
}

bool _isEnabled(WidgetTester tester, String label) {
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, label),
  );
  return button.onPressed != null;
}

void main() {
  testWidgets('An empty field says feeds always work',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(onSubmit: (_) async => true, pending: signal(false)));

    expect(find.text('RSS feeds always work'), findsOneWidget);
    expect(_isEnabled(tester, 'Stash'), isFalse);
  });

  testWidgets('An invalid URL is reported inline and never submitted',
      (WidgetTester tester) async {
    final urls = <String>[];
    await tester.pumpWidget(_host(
      onSubmit: (url) async {
        urls.add(url);
        return true;
      },
      pending: signal(false),
    ));

    await tester.enterText(find.byType(TextField), 'not a url');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pump();

    expect(find.textContaining('Enter a valid http(s) link'), findsOneWidget);
    expect(urls, isEmpty);
  });

  testWidgets('A feed URL activates the chip and is submitted',
      (WidgetTester tester) async {
    final urls = <String>[];
    await tester.pumpWidget(_host(
      onSubmit: (url) async {
        urls.add(url);
        return true;
      },
      pending: signal(false),
    ));

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/feed.xml',
    );
    await tester.pump();
    expect(find.text('Feed supported'), findsOneWidget);
    expect(_isEnabled(tester, 'Stash'), isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pump();

    expect(urls, ['https://example.com/feed.xml']);
  });

  testWidgets('An article on an unsupported site greys the button out',
      (WidgetTester tester) async {
    final urls = <String>[];
    await tester.pumpWidget(_host(
      onSubmit: (url) async {
        urls.add(url);
        return true;
      },
      pending: signal(false),
    ));

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/some/article',
    );
    await tester.pump();

    expect(find.text('Not supported'), findsOneWidget);
    expect(_isEnabled(tester, 'Stash'), isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pump();

    expect(urls, isEmpty);
  });

  testWidgets('The badge explains what stashes well',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(onSubmit: (_) async => true, pending: signal(false)));

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/some/article',
    );
    await tester.pump();

    await tester.tap(find.text('Not supported'));
    await tester.pumpAndSettle();

    expect(find.text('What stashes well'), findsOneWidget);
    expect(find.text('Not yet — no sites are supported.'), findsOneWidget);
  });

  testWidgets('The button is pending while the write runs',
      (WidgetTester tester) async {
    final pending = signal(false);
    await tester.pumpWidget(_host(onSubmit: (_) async => true, pending: pending));

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/feed.xml',
    );
    await tester.pump();
    expect(find.text('Stash'), findsOneWidget);

    pending.value = true;
    await tester.pump();

    expect(find.text('Stashing…'), findsOneWidget);
    expect(find.text('Stash'), findsNothing);
  });
}
