// The stash service on its own: it fetches a feed and keeps it in memory.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/services/stash_service.dart';

import 'fixtures/feed_fixture.dart';

void main() {
  test('a feed is stashed with its entries', () async {
    final service = serviceServing(feedXml);

    final item = await service.stash('https://example.com/feed.xml');

    expect(item.isFeed, isTrue);
    expect(item.title, 'Stashify Weekly');
    expect(item.domain, 'example.com');
    expect(item.url, 'https://example.com/feed.xml');
    expect(item.entries, hasLength(2));

    final first = item.entries.first;
    expect(first.title, 'Reading on the train');
    expect(first.link, 'https://example.com/reading-on-the-train');
    expect(first.summary, 'Why offline still wins');
    expect(first.publishedAt, DateTime.utc(2020, 10, 5, 12));

    final second = item.entries.last;
    expect(second.title, 'Second entry');
    expect(second.publishedAt, isNull);
  });

  test('the stashed feed lands in the items signal', () async {
    final service = serviceServing(feedXml);

    expect(service.items.value, isEmpty);

    final item = await service.stash('https://example.com/feed.xml');

    expect(service.items.value, [item]);
  });

  test('a second feed lands on top of the first', () async {
    final service = serviceServing(feedXml);

    final first = await service.stash('https://example.com/feed.xml');
    final second = await service.stash('https://example.com/other.xml');

    expect(service.items.value, [second, first]);
  });

  test('a link that is not a link is refused', () async {
    final service = serviceServing(feedXml);

    await expectLater(
      service.stash('not a url'),
      throwsA(isA<StashException>()),
    );
    expect(service.items.value, isEmpty);
  });

  test('a host that answers with an error fails the stash', () async {
    final service = serviceServing('Not found', status: 404);

    await expectLater(
      service.stash('https://example.com/feed.xml'),
      throwsA(
        isA<StashException>().having(
          (e) => e.message,
          'message',
          contains('404'),
        ),
      ),
    );
    expect(service.items.value, isEmpty);
  });

  test('a host that cannot be reached fails the stash', () async {
    final service = StashService(
      client: MockClient((request) async => throw http.ClientException('down')),
    );

    await expectLater(
      service.stash('https://example.com/feed.xml'),
      throwsA(isA<StashException>()),
    );
    expect(service.items.value, isEmpty);
  });

  test('a page that is not a feed is not stashed', () async {
    final service = serviceServing(pageHtml);

    await expectLater(
      service.stash('https://example.com/feed.xml'),
      throwsA(
        isA<StashException>().having(
          (e) => e.message,
          'message',
          contains('not a feed'),
        ),
      ),
    );
    expect(service.items.value, isEmpty);
  });

  test('remove takes the item out and restore puts it back', () async {
    final service = serviceServing(feedXml);
    final item = await service.stash('https://example.com/feed.xml');

    service.remove(item);
    expect(service.items.value, isEmpty);

    service.restore(item, 0);
    expect(service.items.value, [item]);
  });
}
