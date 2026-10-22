// The feed read module: downloading entries for offline reading.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:stashify/models/article.dart';
import 'package:stashify/models/stash_item.dart';
import 'package:stashify/screens/feed_screen.dart';
import 'package:stashify/services/stash_service.dart';

const _pageHtml = '''
<html><head><title>Fast validators | Log</title></head><body>
<article><header><h1>Fast validators</h1></header>
<div id="blog-content">
<h2>Summary</h2>
<p>One pass beats two.</p>
</div></article></body></html>
''';

StashItem _feed({List<StashEntry> entries = const []}) => StashItem(
  id: 's1',
  url: 'https://example.com/feed.xml',
  title: 'Stashify Weekly',
  domain: 'example.com',
  savedAt: DateTime.now(),
  isFeed: true,
  entries: entries,
);

StashService _serviceServing(
  String body, {
  int status = 200,
  Duration delay = Duration.zero,
}) {
  return StashService(
    client: MockClient((_) async {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      return http.Response(body, status);
    }),
  );
}

Widget _screen(
  StashItem feed,
  StashService service, {
  OpenBrowser? openBrowser,
  Future<bool> Function()? isOnline,
}) => MaterialApp(
  home: FeedScreen(
    feed: feed,
    service: service,
    openBrowser: openBrowser ?? (_, _) {},
    isOnline: isOnline ?? () async => true,
  ),
);

Future<StashItem> _seed(StashService service, List<StashEntry> entries) async {
  final feed = _feed(entries: entries);
  await service.restore(feed, 0);
  return feed;
}

void main() {
  testWidgets('Read downloads a supported entry, then opens it', (
    WidgetTester tester,
  ) async {
    final service = _serviceServing(
      _pageHtml,
      delay: const Duration(milliseconds: 50),
    );
    final feed = await _seed(service, [
      StashEntry(
        title: 'Fast validators',
        link: 'https://albetnv.dev/blog/fast',
        summary: 'One pass beats two',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ]);
    await tester.pumpWidget(_screen(feed, service));

    expect(find.widgetWithText(TextButton, 'Read'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Read'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Downloading…'), findsOneWidget);
    await tester.pumpAndSettle();

    // The reader opens on the downloaded article.
    expect(find.text('Fast validators'), findsWidgets);
    expect(find.text('Summary'), findsOneWidget);

    // Back on the feed, the row carries the offline mark.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.offline_pin_outlined), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Read'), findsOneWidget);
  });

  testWidgets('A cached entry opens without touching the network', (
    WidgetTester tester,
  ) async {
    final service = _serviceServing('nope', status: 500);
    final feed = await _seed(service, [
      const StashEntry(
        title: 'Cached entry',
        link: 'https://albetnv.dev/blog/cached',
        article: Article(
          title: 'Cached entry',
          blocks: [
            ArticleParagraph([ArticleText('Saved body.')]),
          ],
        ),
      ),
    ]);
    await tester.pumpWidget(_screen(feed, service));

    expect(find.byIcon(Icons.offline_pin_outlined), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Read'));
    await tester.pumpAndSettle();

    expect(find.text('Cached entry'), findsWidgets);
    expect(find.text('Saved body.'), findsOneWidget);
  });

  testWidgets('A failed download keeps the entry downloadable', (
    WidgetTester tester,
  ) async {
    final service = _serviceServing('nope', status: 404);
    final feed = await _seed(service, [
      StashEntry(
        title: 'Fast validators',
        link: 'https://albetnv.dev/blog/fast',
      ),
    ]);
    await tester.pumpWidget(_screen(feed, service));

    await tester.tap(find.widgetWithText(TextButton, 'Read'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not fetch albetnv.dev (404).'),
      findsOneWidget,
    );
    // Nothing cached: the row still offers Read, with no offline mark.
    expect(find.widgetWithText(TextButton, 'Read'), findsOneWidget);
    expect(find.byIcon(Icons.offline_pin_outlined), findsNothing);
  });

  testWidgets('A linked entry opens its live page in the app browser', (
    WidgetTester tester,
  ) async {
    final service = _serviceServing(_pageHtml);
    final feed = await _seed(service, [
      StashEntry(
        title: 'Elsewhere',
        link: 'https://example.com/elsewhere',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      const StashEntry(title: 'No link at all'),
    ]);
    final opened = <Uri>[];
    await tester.pumpWidget(
      _screen(feed, service, openBrowser: (_, url) => opened.add(url)),
    );

    // The linked entry reads live; the linkless one says so.
    expect(find.widgetWithText(TextButton, 'Read'), findsOneWidget);
    expect(find.text('Not supported'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Read'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://example.com/elsewhere')]);

    await tester.tap(find.text('Not supported'));
    await tester.pumpAndSettle();
    expect(find.text('This entry has no link to open.'), findsOneWidget);
  });

  testWidgets('An offline tap explains instead of opening', (
    WidgetTester tester,
  ) async {
    final service = _serviceServing(_pageHtml);
    final feed = await _seed(service, [
      StashEntry(
        title: 'Elsewhere',
        link: 'https://example.com/elsewhere',
      ),
    ]);
    var opened = 0;
    await tester.pumpWidget(
      _screen(
        feed,
        service,
        openBrowser: (_, _) => opened++,
        isOnline: () async => false,
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Read'));
    await tester.pumpAndSettle();

    expect(
      find.text('Needs a connection to open the live page.'),
      findsOneWidget,
    );
    expect(opened, 0);
  });
}
