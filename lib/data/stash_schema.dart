import 'package:sqlite_query_forge/sqlite_query_forge.dart';

import 'package:stashify/data/article_codec.dart';
import 'package:stashify/models/article.dart';
import 'package:stashify/models/stash_item.dart';

/// One stashed feed or article, as stored.
///
/// Flat by design: a feed's entries live in [entries], assembled by the
/// store. Mappers read leniently so an `ALTER TABLE ... ADD COLUMN` that
/// ships without a default can never break loading old rows.
class StashItemRow {
  const StashItemRow({
    required this.id,
    required this.url,
    required this.title,
    required this.domain,
    required this.savedAt,
    required this.isFeed,
    required this.readMinutes,
    required this.position,
    this.article,
  });

  final String id;
  final String url;
  final String title;
  final String domain;
  final DateTime savedAt;
  final bool isFeed;
  final int readMinutes;

  /// Explicit order: newest first, and `restore(index)` reinserts anywhere.
  final int position;
  final Article? article;

  factory StashItemRow.fromRow(Map<String, Object?> row) => StashItemRow(
    id: row['id'] as String? ?? '',
    url: row['url'] as String? ?? '',
    title: row['title'] as String? ?? '',
    domain: row['domain'] as String? ?? '',
    savedAt: DateTime.fromMillisecondsSinceEpoch(
      row['saved_at'] is int ? row['saved_at'] as int : 0,
      isUtc: true,
    ),
    isFeed: row['is_feed'] == 1,
    readMinutes: row['read_minutes'] is int ? row['read_minutes'] as int : 0,
    position: row['position'] is int ? row['position'] as int : 0,
    article: ArticleCodec.tryDecodeString(row['article_json'] as String?),
  );

  Map<String, Object?> toMap() {
    final body = article;
    return {
      'id': id,
      'url': url,
      'title': title,
      'domain': domain,
      'saved_at': savedAt.millisecondsSinceEpoch,
      'is_feed': isFeed ? 1 : 0,
      'read_minutes': readMinutes,
      'position': position,
      'article_json': body == null ? null : ArticleCodec.encodeString(body),
    };
  }

  StashItem toItem({List<StashEntry> entries = const []}) => StashItem(
    id: id,
    url: url,
    title: title,
    domain: domain,
    savedAt: savedAt,
    isFeed: isFeed,
    readMinutes: readMinutes,
    entries: entries,
    article: article,
  );
}

/// One entry of a stashed feed, as stored.
class EntryRow {
  const EntryRow({
    this.id,
    required this.feedId,
    required this.title,
    this.link,
    this.summary,
    this.publishedAt,
    required this.position,
    this.article,
  });

  /// Null before the first insert; the table auto-assigns it.
  final int? id;
  final String feedId;
  final String title;
  final String? link;
  final String? summary;
  final DateTime? publishedAt;
  final int position;
  final Article? article;

  factory EntryRow.fromRow(Map<String, Object?> row) {
    final published = row['published_at'];
    return EntryRow(
      id: row['id'] is int ? row['id'] as int : null,
      feedId: row['feed_id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      link: row['link'] as String?,
      summary: row['summary'] as String?,
      publishedAt: published is int
          ? DateTime.fromMillisecondsSinceEpoch(published, isUtc: true)
          : null,
      position: row['position'] is int ? row['position'] as int : 0,
      article: ArticleCodec.tryDecodeString(row['article_json'] as String?),
    );
  }

  Map<String, Object?> toMap() {
    final body = article;
    return {
      if (id != null) 'id': id,
      'feed_id': feedId,
      'title': title,
      'link': link,
      'summary': summary,
      'published_at': publishedAt?.millisecondsSinceEpoch,
      'position': position,
      'article_json': body == null ? null : ArticleCodec.encodeString(body),
    };
  }

  StashEntry toEntry() => StashEntry(
    title: title,
    link: link,
    summary: summary,
    publishedAt: publishedAt,
    article: article,
  );
}

/// The library table. `url` is unique: re-stashing a link upserts instead
/// of duplicating the card.
final class ItemsTable extends Table<StashItemRow> {
  const ItemsTable() : super('items', mapper: StashItemRow.fromRow);

  Column<String> get id => const Column.text('id', nullable: false);
  Column<String> get url =>
      const Column.text('url', nullable: false, unique: true);
  Column<String> get title => const Column.text('title', nullable: false);
  Column<String> get domain => const Column.text('domain', nullable: false);
  Column<int> get savedAt => const Column.integer('saved_at', nullable: false);
  Column<int> get isFeed => const Column.integer('is_feed', nullable: false);
  Column<int> get readMinutes =>
      const Column.integer('read_minutes', nullable: false);
  Column<int> get position => const Column.integer('position', nullable: false);
  Column<String> get articleJson => const Column.text('article_json');

  @override
  List<Column<Object>> get columns => [
    id,
    url,
    title,
    domain,
    savedAt,
    isFeed,
    readMinutes,
    position,
    articleJson,
  ];
}

/// A feed's entries. No DDL foreign key: the bridge only carries FKs on
/// integer columns and ids are strings, so the store deletes an item's
/// entries in the same transaction as the item.
final class EntriesTable extends Table<EntryRow> {
  const EntriesTable() : super('entries', mapper: EntryRow.fromRow);

  Column<int> get id => const Column.id();
  Column<String> get feedId => const Column.text('feed_id', nullable: false);
  Column<String> get title => const Column.text('title', nullable: false);
  Column<String> get link => const Column.text('link');
  Column<String> get summary => const Column.text('summary');
  Column<int> get publishedAt => const Column.integer('published_at');
  Column<int> get position => const Column.integer('position', nullable: false);
  Column<String> get articleJson => const Column.text('article_json');

  @override
  List<Column<Object>> get columns => [
    id,
    feedId,
    title,
    link,
    summary,
    publishedAt,
    position,
    articleJson,
  ];
}

const items = ItemsTable();
const entries = EntriesTable();

/// The v1 schema: query declarations bridged to the migrator, plus the one
/// piece columns don't carry — the composite unique on entries.
MigrationSchema stashSchema() =>
    schemaOf(version: 1, tables: [items, entries]).extend(
      indexes: {
        'entries': [
          SchemaIndex(columns: ['feed_id', 'link'], unique: true),
        ],
      },
    );
