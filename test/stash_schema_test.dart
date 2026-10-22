// The v1 schema: the bridge creates the tables, the composite unique
// holds, and rows round-trip through Forge with their mappers.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3_driver_forge/sqlite3_driver_forge.dart';
import 'package:sqlite_query_forge/sqlite_query_forge.dart';
import 'package:sqlite_schema_forge/sqlite_schema_forge.dart';

import 'package:stashify/data/stash_schema.dart';
import 'package:stashify/models/article.dart';

StashItemRow _item() => StashItemRow(
  id: 's1',
  url: 'https://example.com/feed.xml',
  title: 'Stashify Weekly',
  domain: 'example.com',
  savedAt: DateTime.utc(2020, 10, 5, 12),
  isFeed: true,
  readMinutes: 0,
  position: 0,
  article: null,
);

EntryRow _entry(String link, int position, {Article? article}) => EntryRow(
  feedId: 's1',
  title: 'Entry $position',
  link: link,
  summary: 'Summary $position',
  publishedAt: DateTime.utc(2020, 10, 5, 12),
  position: position,
  article: article,
);

Future<Forge> _migrated(SqliteDriver driver) async {
  await driver.connect();
  final result = await SqliteSchemaForge.migrate(
    db: ForgeDatabaseExecutor(driver),
    targetSchema: stashSchema(),
    allowDestructive: false,
  );
  expect(result.migrated, isTrue);
  expect(result.executedSql, isNotEmpty);
  return Forge(driver);
}

void main() {
  test('migrating twice only migrates once', () async {
    final driver = SqliteDriver.inMemory();
    try {
      await _migrated(driver);

      final version = await driver.query('PRAGMA user_version');
      expect(version.single['user_version'], 1);

      final again = await SqliteSchemaForge.migrate(
        db: ForgeDatabaseExecutor(driver),
        targetSchema: stashSchema(),
        allowDestructive: false,
      );
      expect(again.migrated, isFalse);
    } finally {
      await driver.disconnect();
    }
  });

  test('a fresh plan has no destructive steps', () async {
    final driver = SqliteDriver.inMemory();
    await driver.connect();
    try {
      final plan = await SqliteSchemaForge.plan(
        db: ForgeDatabaseExecutor(driver),
        targetSchema: stashSchema(),
      );
      expect(plan.hasDestructiveChanges, isFalse);
      expect(plan.isUpToDate, isFalse);
    } finally {
      await driver.disconnect();
    }
  });

  test('items round-trip with their mapper', () async {
    final driver = SqliteDriver.inMemory();
    try {
      final forge = await _migrated(driver);

      await forge.insertInto(items).values(_item().toMap()).execute();

      final row = await forge
          .selectFrom(items)
          .where(items.id.eq('s1'))
          .getSingle();
      expect(row.url, 'https://example.com/feed.xml');
      expect(row.title, 'Stashify Weekly');
      expect(row.isFeed, isTrue);
      expect(row.savedAt, DateTime.utc(2020, 10, 5, 12));
      expect(row.position, 0);

      final asItem = row.toItem();
      expect(asItem.domain, 'example.com');
      expect(asItem.entries, isEmpty);
    } finally {
      await driver.disconnect();
    }
  });

  test('entries keep feed order and the composite unique holds', () async {
    final driver = SqliteDriver.inMemory();
    try {
      final forge = await _migrated(driver);
      await forge.insertInto(items).values(_item().toMap()).execute();

      await forge.insertInto(entries).valuesAll([
        _entry('https://example.com/b', 1).toMap(),
        _entry('https://example.com/a', 0).toMap(),
      ]).execute();

      final rows = await forge.selectFrom(entries).orderBy([
        OrderBy(entries.position),
      ]).getMany();
      expect(rows.map((e) => e.link), [
        'https://example.com/a',
        'https://example.com/b',
      ]);

      await expectLater(
        forge
            .insertInto(entries)
            .values(_entry('https://example.com/a', 2).toMap())
            .execute(),
        throwsA(isA<Exception>()),
      );
    } finally {
      await driver.disconnect();
    }
  });

  test('an article body round-trips through article_json', () async {
    const article = Article(
      title: 'Fast validators',
      blocks: [
        ArticleParagraph([ArticleText('One pass beats two.')]),
      ],
    );
    final driver = SqliteDriver.inMemory();
    try {
      final forge = await _migrated(driver);

      await forge
          .insertInto(items)
          .values(
            StashItemRow(
              id: 's2',
              url: 'https://albetnv.dev/blog/fast',
              title: 'Fast validators',
              domain: 'albetnv.dev',
              savedAt: DateTime.utc(2024, 1, 1),
              isFeed: false,
              readMinutes: 1,
              position: 0,
              article: article,
            ).toMap(),
          )
          .execute();

      final row = await forge
          .selectFrom(items)
          .where(items.id.eq('s2'))
          .getSingle();
      expect(row.article, isNotNull);
      expect(row.article!.title, 'Fast validators');
      expect(
        ((row.article!.blocks.single as ArticleParagraph).content.single
                as ArticleText)
            .text,
        'One pass beats two.',
      );
    } finally {
      await driver.disconnect();
    }
  });

  test('deleting an item leaves its entries behind', () async {
    // No DDL foreign key by design (ids are strings, the bridge only
    // carries FKs on integer columns): the store deletes entries in the
    // same transaction as the item. This locks in that contract's premise.
    final driver = SqliteDriver.inMemory();
    try {
      final forge = await _migrated(driver);
      await forge.insertInto(items).values(_item().toMap()).execute();
      await forge
          .insertInto(entries)
          .values(_entry('https://example.com/a', 0).toMap())
          .execute();

      await forge.deleteFrom(items).where(items.id.eq('s1')).execute();

      expect(await forge.selectFrom(entries).count(), 1);
    } finally {
      await driver.disconnect();
    }
  });
}
