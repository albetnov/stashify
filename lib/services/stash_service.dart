import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'package:signals/signals.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/utils/link_utils.dart';

class StashService {
  StashService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Signal<List<StashItem>> _items = signal([]);

  static const _timeout = Duration(seconds: 15);
  static const _userAgent = 'Stashify/0.1';

  /// The stashed items, newest first.
  ReadonlySignal<List<StashItem>> get items => _items;

  /// Stashes [raw] and returns the stashed item.
  ///
  /// A feed is fetched and parsed, and it lands in the list with its
  /// entries. The item lands in the list when the write is done. A failed
  /// write adds nothing: the card tells the user, and the link stays in the
  /// field.
  Future<StashItem> stash(String raw) async {
    if (supportFor(raw) == UrlSupport.none) {
      throw const StashException('That does not look like a link.');
    }

    final uri = Uri.parse(raw);

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

    final RssFeed feed;
    try {
      feed = RssFeed.parse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } catch (_) {
      throw const StashException('That link is not a feed.');
    }

    final title = feed.title?.trim();
    final item = StashItem(
      id: 's${DateTime.now().microsecondsSinceEpoch}',
      url: raw,
      title: title == null || title.isEmpty ? domainOf(raw) : title,
      domain: domainOf(raw),
      savedAt: DateTime.now(),
      isFeed: true,
      entries: feed.items.map(_entryOf).toList(),
    );

    _items.value = [item, ..._items.peek()];
    return item;
  }

  /// Takes [item] out of the stash.
  void remove(StashItem item) {
    final items = [..._items.peek()]..removeWhere((e) => e.id == item.id);
    _items.value = items;
  }

  /// Puts [item] back into the stash at [index].
  void restore(StashItem item, int index) {
    final items = [..._items.peek()];
    final at = index < 0 ? 0 : (index > items.length ? items.length : index);
    items.insert(at, item);
    _items.value = items;
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
