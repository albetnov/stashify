// Interaction test for the stash flow. The feed is served by a fake client,
// so the test never touches the network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fetch_forge/fetch_forge.dart';
import 'package:stashify/main.dart';
import 'package:stashify/services/service_locator.dart';
import 'package:stashify/services/stash_service.dart';

import 'fixtures/feed_fixture.dart';
import 'test_helper.dart';

void main() {
  setUp(() async {
    mockPathProvider();
    await getIt.reset();
    getIt.registerFactory<StashService>(
      () => serviceServing(
        feedXml,
        delay: const Duration(milliseconds: 50),
        queryClient: getIt<QueryClient>(),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('Feed URL activates chip and stashes with progress', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() => setupServicesAsync());
    await tester.pumpWidget(const StashifyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste article or feed URL'),
      'https://example.com/feed.xml',
    );
    await tester.pump();
    expect(find.text('Feed supported'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pump();
    expect(find.text('Stashing…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Stashify Weekly'), findsOneWidget);
    expect(find.text('Saved for offline reading.'), findsOneWidget);
  });

  testWidgets('Tapping a stashed feed opens its entries', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() => setupServicesAsync());
    await tester.pumpWidget(const StashifyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste article or feed URL'),
      'https://example.com/feed.xml',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stashify Weekly'));
    await tester.pumpAndSettle();

    expect(find.text('2 entries · example.com'), findsOneWidget);
    expect(find.text('Reading on the train'), findsOneWidget);
    expect(find.text('Why offline still wins'), findsOneWidget);
  });

  testWidgets('Invalid URL shows an inline error', (WidgetTester tester) async {
    await tester.runAsync(() => setupServicesAsync());
    await tester.pumpWidget(const StashifyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste article or feed URL'),
      'not a url',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pump();
    expect(find.textContaining('Enter a valid http(s) link'), findsOneWidget);
  });
}
