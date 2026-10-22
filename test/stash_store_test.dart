import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3_driver_forge/sqlite3_driver_forge.dart';
import 'package:sqlite_query_forge/sqlite_query_forge.dart';
import 'package:sqlite_schema_forge/sqlite_schema_forge.dart';

import 'package:stashify/data/stash_schema.dart';
import 'package:stashify/data/stash_store.dart';
import 'package:stashify/models/article.dart';
import 'package:stashify/models/stash_item.dart';

Future<StashStore> _store() async {
  final driver = SqliteDriver.inMemory();
  await driver.connect();
  await SqliteSchemaForge.migrate(
    db: ForgeDatabaseExecutor(driver),
    targetSchema: stashSchema(),
    allowDestructive: false,
  );
  return StashStore(Forge(driver));
}

void main() {
  test('saves and reloads an article', () async {
    final store = await _store();
    final item = StashItem(
      id: 'a1',
      url: 'https://x.dev/a',
      title: 'A',
      domain: 'x.dev',
      savedAt: DateTime.utc(2024, 1, 1),
      article: const Article(title: 'A', blocks: []),
    );
    await store.saveItem(
      StashItemRow(
        id: item.id,
        url: item.url,
        title: item.title,
        domain: item.domain,
        savedAt: item.savedAt,
        isFeed: false,
        readMinutes: 1,
        position: 0,
        article: item.article,
      ),
      const [],
    );
    final loaded = await store.loadLibrary();
    expect(loaded, hasLength(1));
    expect(loaded.first.title, 'A');
    expect(loaded.first.article, isNotNull);
  });

  test('saves and reloads a feed with entries', () async {
    final store = await _store();
    final item = StashItem(
      id: 'f1',
      url: 'https://x.dev/feed.xml',
      title: 'Feed',
      domain: 'x.dev',
      savedAt: DateTime.utc(2024, 1, 1),
      isFeed: true,
      entries: const [StashEntry(title: 'E1', link: 'https://x.dev/e1')],
    );
    await store.saveItem(
      StashItemRow(
        id: item.id,
        url: item.url,
        title: item.title,
        domain: item.domain,
        savedAt: item.savedAt,
        isFeed: true,
        readMinutes: 0,
        position: 0,
      ),
      [
        EntryRow(
          feedId: item.id,
          title: 'E1',
          link: 'https://x.dev/e1',
          position: 0,
        ),
      ],
    );
    final loaded = await store.loadLibrary();
    expect(loaded.first.entries, hasLength(1));
    expect(loaded.first.entries.first.title, 'E1');
  });

  test('remove deletes entries too', () async {
    final store = await _store();
    await store.saveItem(
      StashItemRow(
        id: 'f1',
        url: 'https://x.dev/feed.xml',
        title: 'Feed',
        domain: 'x.dev',
        savedAt: DateTime.utc(2024, 1, 1),
        isFeed: true,
        readMinutes: 0,
        position: 0,
      ),
      [EntryRow(feedId: 'f1', title: 'E1', position: 0)],
    );
    await store.removeItem('f1');
    expect(await store.loadLibrary(), isEmpty);
  });
}
