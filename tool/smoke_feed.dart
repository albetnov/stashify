// ignore_for_file: avoid_print
// Smoke test: fetch a real feed and print what came back.
import 'package:stashify/models/stash_item.dart';
import 'package:stashify/services/stash_service.dart';

Future<void> main() async {
  final service = StashService();

  final item = await service.stash('https://feeds.bbci.co.uk/news/rss.xml');

  print('title:   ${item.title}');
  print('domain:  ${item.domain}');
  print('isFeed:  ${item.isFeed}');
  print('entries: ${item.entries.length}');
  for (final entry in item.entries.take(3)) {
    print('  - ${entry.title}');
    print('    ${entry.publishedAt}  ${entry.link}');
    print('    ${entry.summary}');
  }
  print('in the signal: ${service.items.value.length}');

  try {
    await service.stash('https://example.com/not-a-feed');
  } on StashException catch (e) {
    print('not a feed -> ${e.message}');
  }

  try {
    await service.stash('https://example.com/404');
  } on StashException catch (e) {
    print('404 -> ${e.message}');
  }
}
