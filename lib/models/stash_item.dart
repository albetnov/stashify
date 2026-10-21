import 'package:stashify/models/article.dart';

/// Thrown when a stash write fails.
///
/// The write that throws it adds nothing to the stash: the card tells the
/// user and keeps the link in the field.
class StashException implements Exception {
  const StashException(this.message);

  final String message;

  @override
  String toString() => 'StashException: $message';
}

/// One entry of a stashed feed.
class StashEntry {
  const StashEntry({
    required this.title,
    this.link,
    this.summary,
    this.publishedAt,
  });

  final String title;
  final String? link;
  final String? summary;
  final DateTime? publishedAt;
}

class StashItem {
  StashItem({
    required this.id,
    required this.url,
    required this.title,
    required this.domain,
    required this.savedAt,
    this.isFeed = false,
    this.readMinutes = 0,
    this.entries = const [],
    this.article,
  });

  final String id;
  final String url;
  final String title;
  final String domain;
  final DateTime savedAt;
  final bool isFeed;
  final int readMinutes;

  /// The entries of a stashed feed, empty for an article.
  final List<StashEntry> entries;

  /// The parsed body of a stashed article, null for a feed.
  final Article? article;
}
