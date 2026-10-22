import 'package:sqlite_query_forge/sqlite_query_forge.dart';

import 'package:stashify/data/article_codec.dart';
import 'package:stashify/data/stash_schema.dart';
import 'package:stashify/models/article.dart';
import 'package:stashify/models/stash_item.dart';

/// Repository over the v1 SQLite schema.
///
/// Stateless holder over a [Forge]: open once, share it. Every public method
/// runs inside a single transaction so item + entries stay consistent.
class StashStore {
  const StashStore(this.forge);

  final Forge forge;

  /// Loads the library: items with their entries assembled, newest first.
  Future<List<StashItem>> loadLibrary() async {
    final rows = await forge.selectFrom(items).orderBy([
      OrderBy(items.position),
    ]).getMany();

    final result = <StashItem>[];
    for (final row in rows) {
      final entryRows = await forge
          .selectFrom(entries)
          .where(entries.feedId.eq(row.id))
          .orderBy([OrderBy(entries.position)])
          .getMany();
      result.add(
        row.toItem(entries: entryRows.map((e) => e.toEntry()).toList()),
      );
    }
    return result;
  }

  /// Persists [item] and its [entryRows] in one transaction.
  ///
  /// Re-stashing a URL upserts: the item row updates, entries are replaced.
  Future<void> saveItem(StashItemRow item, List<EntryRow> entryRows) async {
    await forge.transaction((tx) async {
      // Re-stashing a URL replaces the old row so the new id stays
      // consistent with the in-memory item.
      final existingRows = await tx
          .selectFrom(items)
          .where(items.url.eq(item.url))
          .getMany();
      if (existingRows.isNotEmpty) {
        final oldId = existingRows.first.id;
        await tx.deleteFrom(entries).where(entries.feedId.eq(oldId)).execute();
        await tx.deleteFrom(items).where(items.id.eq(oldId)).execute();
      }

      // Newest first: the new item lands above every existing row.
      final count = await tx.selectFrom(items).count();
      final position = count == 0 ? 0 : (await _minPosition(tx)) - 1;

      final row = StashItemRow(
        id: item.id,
        url: item.url,
        title: item.title,
        domain: item.domain,
        savedAt: item.savedAt,
        isFeed: item.isFeed,
        readMinutes: item.readMinutes,
        position: position,
        article: item.article,
      );

      await tx.insertInto(items).values(row.toMap()).execute();

      final persisted = await tx
          .selectFrom(items)
          .where(items.url.eq(item.url))
          .getSingle();

      await tx
          .deleteFrom(entries)
          .where(entries.feedId.eq(persisted.id))
          .execute();

      if (entryRows.isNotEmpty) {
        await tx.insertInto(entries).valuesAll([
          for (final e in entryRows)
            EntryRow(
              feedId: persisted.id,
              title: e.title,
              link: e.link,
              summary: e.summary,
              publishedAt: e.publishedAt,
              position: e.position,
              article: e.article,
            ).toMap(),
        ]).execute();
      }
    });
  }

  Future<int> _minPosition(Forge tx) async {
    final rows = await tx.query(
      SelectStatement(
        from: items.source,
        columns: [const RawSql('MIN(position) AS m')],
      ),
    );
    if (rows.isEmpty || rows.first['m'] == null) return 0;
    return (rows.first['m'] as num).toInt();
  }

  /// Removes an item and its entries in one transaction.
  Future<void> removeItem(String id) async {
    await forge.transaction((tx) async {
      await tx.deleteFrom(entries).where(entries.feedId.eq(id)).execute();
      await tx.deleteFrom(items).where(items.id.eq(id)).execute();
    });
  }

  /// Caches a downloaded article body on one feed entry.
  Future<void> saveEntryArticle(
    String feedId,
    String? link,
    Article article,
  ) async {
    await forge
        .update(entries)
        .where(link == null ? entries.link.isNull : entries.link.eq(link))
        .values({'article_json': ArticleCodec.encodeString(article)})
        .execute();
  }

  /// Re-writes the positions of [itemIds] in order (newest first).
  Future<void> reorder(List<String> itemIds) async {
    await forge.transaction((tx) async {
      for (var i = 0; i < itemIds.length; i++) {
        await tx.update(items).where(items.id.eq(itemIds[i])).values({
          'position': i,
        }).execute();
      }
    });
  }
}
