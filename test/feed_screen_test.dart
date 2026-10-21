// The feed screen: the entries of a stashed feed and the Read action.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/screens/feed_screen.dart';
import 'package:stashify/services/stash_service.dart';

StashItem _feed({List<StashEntry> entries = const []}) => StashItem(
      id: 's1',
      url: 'https://example.com/feed.xml',
      title: 'Stashify Weekly',
      domain: 'example.com',
      savedAt: DateTime.now(),
      isFeed: true,
      entries: entries,
    );

List<StashEntry> _entries() => [
      StashEntry(
        title: 'Reading on the train',
        link: 'https://example.com/one',
        summary: 'Why offline still wins',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      StashEntry(
        title: 'Second entry',
        link: 'https://example.com/two',
      ),
    ];

Widget _screen(StashItem feed) {
  final service = StashService();
  service.restore(feed, 0);
  return MaterialApp(home: FeedScreen(feed: feed, service: service));
}

void main() {
  testWidgets('The screen lists the entries of the feed',
      (WidgetTester tester) async {
    await tester.pumpWidget(_screen(_feed(entries: _entries())));

    expect(find.text('Stashify Weekly'), findsOneWidget);
    expect(find.text('2 entries · example.com'), findsOneWidget);
    expect(find.text('Reading on the train'), findsOneWidget);
    expect(find.text('2h ago'), findsOneWidget);
    expect(find.text('Why offline still wins'), findsOneWidget);
    expect(find.text('Second entry'), findsOneWidget);
    // example.com has no article adapter, so neither entry can download.
    expect(find.text('Not supported'), findsNWidgets(2));
    expect(find.widgetWithText(TextButton, 'Read'), findsNothing);
  });

  testWidgets('An entry with no readable link explains itself',
      (WidgetTester tester) async {
    await tester.pumpWidget(_screen(_feed(entries: _entries())));

    await tester.tap(find.text('Not supported').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Articles from example.com aren’t supported yet.'),
      findsOneWidget,
    );
    expect(find.text('example.com · 2h ago'), findsOneWidget);
  });

  testWidgets('A feed with nothing in it says so',
      (WidgetTester tester) async {
    await tester.pumpWidget(_screen(_feed()));

    expect(find.text('Nothing in this feed'), findsOneWidget);
    expect(
      find.text('There was nothing in it when it was stashed.'),
      findsOneWidget,
    );
  });

  testWidgets('The entries hold up on a small screen with large text',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0; // 360x640 logical
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _screen(_feed(entries: _entries())),
      ),
    );

    expect(find.text('Reading on the train'), findsOneWidget);
    expect(find.text('Not supported'), findsNWidgets(2));
  });

  testWidgets('The screen holds up at a large font scale',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0; // 360x640 logical
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _screen(_feed(entries: _entries())),
      ),
    );

    expect(find.text('Stashify Weekly'), findsOneWidget);
    expect(find.text('2 entries · example.com'), findsOneWidget);
    expect(find.text('Reading on the train'), findsOneWidget);

    // The app bar clips its title silently, so the line under the title
    // has to be measured, not waited for.
    final meta = tester.getRect(find.text('2 entries · example.com'));
    final bar = tester.getRect(find.byType(AppBar));
    expect(meta.bottom, lessThanOrEqualTo(bar.bottom));
  });

  testWidgets('A long entry does not overflow its row',
      (WidgetTester tester) async {
    final feed = _feed(
      entries: [
        StashEntry(
          title: 'A headline long enough to need more than the two lines the '
              'row gives it before it ellipsises',
          link: 'https://example.com/one',
          summary: 'A summary long enough to need more than the two lines '
              'the row gives it before it ellipsises, and then some more '
              'words on top of that for good measure.',
          publishedAt: DateTime(2024, 3, 14),
        ),
      ],
    );

    await tester.pumpWidget(_screen(feed));

    expect(find.textContaining('A headline long enough'), findsOneWidget);
    expect(find.text('14 Mar 2024'), findsOneWidget);
  });
}
