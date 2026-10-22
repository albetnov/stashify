import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';


import 'package:fetch_forge/fetch_forge.dart';
import 'package:signals/signals.dart';

import 'package:stashify/data/stash_schema.dart';
import 'package:stashify/data/stash_store.dart';
import 'package:stashify/models/article.dart';
import 'package:stashify/models/stash_item.dart';
import 'package:stashify/services/albetnv_adapter.dart';
import 'package:stashify/services/article_adapter.dart';
import 'package:stashify/utils/link_utils.dart';

/// Shared cache key for the persisted library list.
const String stashLibraryKey = 'stash:library';

class StashService {
  StashService({
    http.Client? client,
    List<ArticleAdapter>? adapters,
    this._store,
    this._queryClient,
  }) : _client = client ?? http.Client(),
       _adapters = adapters ?? const [AlbetnvAdapter()];

  final http.Client _client;
  final List<ArticleAdapter> _adapters;
  final StashStore? _store;
  final QueryClient? _queryClient;
  final List<StashItem> _memoryItems = [];
  final Signal<List<StashItem>> _items = signal([]);

  static const _timeout = Duration(seconds: 15);
  static const _userAgent = 'Stashify/0.1';

  /// The stashed items, newest first.
  /// The stashed items as a signal, for screens that need synchronous reads.
  ReadonlySignal<List<StashItem>> get items => _items;

  Future<List<StashItem>> loadLibrary([int page = 0]) async {
    if (_store != null) return _store.loadLibrary();
    return List<StashItem>.unmodifiable(_memoryItems);
  }

  void _invalidateLibrary() {
    _queryClient?.invalidate(stashLibraryKey);
  }

  /// Stashes [raw] and returns the stashed item.
  ///
  /// A feed is fetched and parsed, and it lands in the list with its
  /// entries. The item lands in the list when the write is done. A failed
  /// write adds nothing: the card tells the user, and the link stays in the
  /// field.
  Future<StashItem> stash(String raw) async {
    switch (supportFor(raw)) {
      case StashSupport.none:
        throw const StashException('That does not look like a link.');
      case StashSupport.unsupportedArticle:
        throw StashException(
          'Articles from ${domainOf(raw)} are not supported yet.',
        );
      case StashSupport.supportedArticle:
        return _stashArticle(raw);
      case StashSupport.feed:
        return _stashFeed(raw);
    }
  }

  Future<StashItem> _stashArticle(String raw) async {
    final uri = Uri.parse(raw);
    final adapter = _adapterFor(uri);
    final body = await _fetch(uri);

    final Article article;
    try {
      article = adapter.parse(body, uri: uri);
    } on ArticleParseException catch (error) {
      throw StashException(error.message);
    }

    final item = StashItem(
      id: 's${DateTime.now().microsecondsSinceEpoch}',
      url: raw,
      title: article.title,
      domain: domainOf(raw),
      savedAt: DateTime.now(),
      readMinutes: article.readMinutes,
      article: article,
    );

    await _persist(item);
    if (_store == null) _memoryItems.insert(0, item);
    _invalidateLibrary();
    _items.value = await loadLibrary();
    return item;
  }

  ArticleAdapter _adapterFor(Uri uri) {
    for (final adapter in _adapters) {
      if (adapter.handles(uri)) return adapter;
    }
    throw StashException('Articles from ${uri.host} are not supported yet.');
  }

  /// Downloads one feed [entry] for offline reading and caches it on the
  /// feed.
  ///
  /// The parsed article is attached to the entry itself, so the library
  /// gains nothing new. An entry that is already cached returns its
  /// article without touching the network. A failed download throws the
  /// user-facing failure and caches nothing.
  Future<Article> fetchEntryArticle(StashItem feed, StashEntry entry) async {
    if (entry.article != null) return entry.article!;

    final link = entry.link?.trim();
    if (link == null || link.isEmpty) {
      throw const StashException('This entry has no link to download.');
    }
    if (!isSupportedArticleHost(link)) {
      throw StashException(
        'Articles from ${domainOf(link)} are not supported yet.',
      );
    }

    final uri = Uri.parse(link);
    final body = await _fetch(uri);

    final Article article;
    try {
      article = _adapterFor(uri).parse(body, uri: uri);
    } on ArticleParseException catch (error) {
      throw StashException(error.message);
    }

    final entries =
        feed.entries
            .map(
              (candidate) =>
                  identical(candidate, entry)
                      ? StashEntry(
                        title: candidate.title,
                        link: candidate.link,
                        summary: candidate.summary,
                        publishedAt: candidate.publishedAt,
                        article: article,
                      )
                      : candidate,
            )
            .toList();
    final updated = StashItem(
      id: feed.id,
      url: feed.url,
      title: feed.title,
      domain: feed.domain,
      savedAt: feed.savedAt,
      isFeed: true,
      entries: entries,
    );
    if (_store != null) {
      await _store.saveEntryArticle(feed.id, entry.link, article);
    } else {
      final idx = _memoryItems.indexWhere((i) => i.id == feed.id);
      if (idx != -1) _memoryItems[idx] = updated;
    }
    _invalidateLibrary();
    _items.value = await loadLibrary();
    return article;
  }

  Future<StashItem> _stashFeed(String raw) async {
    final uri = Uri.parse(raw);
    final body = await _fetch(uri);

    final RssFeed feed;
    try {
      feed = RssFeed.parse(body);
    } catch (_) {
      throw const StashException('That link is not a feed.');
    }

    final title = feed.title?.trim();
    final entries = feed.items.map(_entryOf).toList();
    final item = StashItem(
      id: 's${DateTime.now().microsecondsSinceEpoch}',
      url: raw,
      title: title == null || title.isEmpty ? domainOf(raw) : title,
      domain: domainOf(raw),
      savedAt: DateTime.now(),
      isFeed: true,
      entries: entries,
    );

    await _persist(item);
    if (_store == null) _memoryItems.insert(0, item);
    _invalidateLibrary();
    _items.value = await loadLibrary();
    return item;
  }

  /// Fetches [uri] and returns its body, or throws the user-facing failure.
  Future<String> _fetch(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'user-agent': _userAgent})
          .timeout(_timeout);
    } catch (_) {
      throw StashException('Could not reach ${uri.host}.');
    }

    if (response.statusCode != 200) {
      throw StashException(
        'Could not fetch ${uri.host} (${response.statusCode}).',
      );
    }

    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// Takes [item] out of the stash.
  Future<void> remove(StashItem item) async {
    if (_store != null) await _store.removeItem(item.id);
    _memoryItems.removeWhere((e) => e.id == item.id);
    _invalidateLibrary();
    _items.value = await loadLibrary();
  }

  /// Puts [item] back into the stash at [index].
  Future<void> restore(StashItem item, int index) async {
    if (_store != null) await _persist(item);
    if (_store == null) {
      final at = index < 0
          ? 0
          : (index > _memoryItems.length ? _memoryItems.length : index);
      _memoryItems.insert(at, item);
    }
    _invalidateLibrary();
    _items.value = await loadLibrary();
  }

  Future<void> _persist(StashItem item) async {
    if (_store == null) return;
    final row = StashItemRow(
      id: item.id,
      url: item.url,
      title: item.title,
      domain: item.domain,
      savedAt: item.savedAt,
      isFeed: item.isFeed,
      readMinutes: item.readMinutes,
      position: 0,
      article: item.article,
    );
    final entryRows = item.entries
        .asMap()
        .entries
        .map(
          (e) => EntryRow(
            feedId: item.id,
            title: e.value.title,
            link: e.value.link,
            summary: e.value.summary,
            publishedAt: e.value.publishedAt,
            position: e.key,
            article: e.value.article,
          ),
        )
        .toList();
    try {
      await _store.saveItem(row, entryRows);
    } catch (_) {
      throw const StashException('Could not save that link.');
    }
  }

  StashEntry _entryOf(RssItem entry) {
    final title = entry.title?.trim();
    final summary = entry.description?.trim();
    return StashEntry(
      title: title == null || title.isEmpty ? 'Untitled' : title,
      link: entry.link?.trim(),
      summary: summary == null || summary.isEmpty
          ? entry.content?.value.trim()
          : summary,
      publishedAt: _parseDate(entry.pubDate),
    );
  }

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static final _rfc822 = RegExp(
    r'^(?:[A-Za-z]{3,},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})'
    r'\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(GMT|UTC|Z|[+-]\d{4})?$',
  );

  /// The date of a feed entry: ISO 8601, or the RFC 822 form RSS uses.
  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    final match = _rfc822.firstMatch(trimmed);
    if (match == null) return null;

    final month = _months[match.group(2)!.toLowerCase()];
    if (month == null) return null;

    final zone = match.group(7);
    final offset =
        zone != null && (zone.startsWith('+') || zone.startsWith('-'))
        ? (int.parse(zone.substring(1, 3)) * 60 +
                  int.parse(zone.substring(3, 5))) *
              (zone.startsWith('-') ? -1 : 1)
        : 0;

    return DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.tryParse(match.group(6) ?? '0') ?? 0,
    ).subtract(Duration(minutes: offset));
  }
}
