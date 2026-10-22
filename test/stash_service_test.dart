// The stash service on its own: it fetches a feed and keeps it in memory.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:stashify/models/article.dart';
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

    expect(await service.loadLibrary(), isEmpty);

    final item = await service.stash('https://example.com/feed.xml');

    expect(await service.loadLibrary(), [item]);
  });

  test('a second feed lands on top of the first', () async {
    final service = serviceServing(feedXml);

    final first = await service.stash('https://example.com/feed.xml');
    final second = await service.stash('https://example.com/other.xml');

    expect(await service.loadLibrary(), [second, first]);
  });

  test('a link that is not a link is refused', () async {
    final service = serviceServing(feedXml);

    await expectLater(
      service.stash('not a url'),
      throwsA(isA<StashException>()),
    );
    expect(await service.loadLibrary(), isEmpty);
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
    expect(await service.loadLibrary(), isEmpty);
  });

  test('a host that cannot be reached fails the stash', () async {
    final service = StashService(
      client: MockClient((request) async => throw http.ClientException('down')),
    );

    await expectLater(
      service.stash('https://example.com/feed.xml'),
      throwsA(isA<StashException>()),
    );
    expect(await service.loadLibrary(), isEmpty);
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
    expect(await service.loadLibrary(), isEmpty);
  });

  test('an article on an unsupported site is refused', () async {
    final service = serviceServing(feedXml);

    await expectLater(
      service.stash('https://example.com/some/article'),
      throwsA(
        isA<StashException>().having(
          (e) => e.message,
          'message',
          contains('not supported'),
        ),
      ),
    );
    expect(await service.loadLibrary(), isEmpty);
  });

  test('an article on a supported site is stashed with its body', () async {
    final service = serviceServing('''
<html><body><article>
<header>
  <h1>A stashed article</h1>
  <img src="https://example.com/cover.jpg" alt="Cover">
</header>
<div id="blog-content">
  <p>Read me offline.</p>
</div>
</article></body></html>
''');

    final item = await service.stash('https://albetnv.dev/blog/story');

    expect(item.isFeed, isFalse);
    expect(item.title, 'A stashed article');
    expect(item.domain, 'albetnv.dev');
    expect(item.readMinutes, 1);
    expect(item.article, isNotNull);
    expect(item.article!.coverImageUrl, 'https://example.com/cover.jpg');
    expect(item.article!.blocks.single, isA<ArticleParagraph>());
    expect(await service.loadLibrary(), [item]);
  });

  test('the saved albetnv.dev page is stashed as an article', () async {
    final golden = File('test/fixtures/golden.html').readAsStringSync();
    final service = serviceServing(golden);

    final item = await service.stash(
      'https://albetnv.dev/blog/'
      'validasi-v1-rc-released-with-performance-improvement/',
    );

    expect(item.isFeed, isFalse);
    expect(item.article, isNotNull);
    expect(item.article!.blocks, isNotEmpty);
    expect(item.readMinutes, greaterThan(1));
  });

  test('an article with no readable body fails the stash', () async {
    final service = serviceServing('<html><body>Nothing here.</body></html>');

    await expectLater(
      service.stash('https://albetnv.dev/blog/empty'),
      throwsA(
        isA<StashException>().having(
          (e) => e.message,
          'message',
          contains('no readable article'),
        ),
      ),
    );
    expect(await service.loadLibrary(), isEmpty);
  });

  test('remove takes the item out and restore puts it back', () async {
    final service = serviceServing(feedXml);
    final item = await service.stash('https://example.com/feed.xml');

    service.remove(item);
    expect(await service.loadLibrary(), isEmpty);

    service.restore(item, 0);
    expect(await service.loadLibrary(), [item]);
  });
}
