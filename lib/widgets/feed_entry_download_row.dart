import 'package:fetch_forge/flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import 'package:stashify/models/article.dart';
import 'package:stashify/models/stash_item.dart';
import 'package:stashify/services/stash_service.dart';
import 'package:stashify/widgets/feed_entry_row.dart';

/// One downloadable feed entry with the fetch that downloads it.
class FeedEntryDownloadRow extends StatefulWidget {
  const FeedEntryDownloadRow({
    super.key,
    required this.feed,
    required this.entry,
    required this.service,
    required this.onOpen,
  });

  final StashItem feed;
  final StashEntry entry;
  final StashService service;

  /// Opens the downloaded article. Runs after the fetch settles, never
  /// during a build.
  final void Function(StashItem feed, StashEntry entry, Article article) onOpen;

  @override
  State<FeedEntryDownloadRow> createState() => _FeedEntryDownloadRowState();
}

class _FeedEntryDownloadRowState extends State<FeedEntryDownloadRow> {
  static final RetryPolicy _retry = RetryPolicy(
    maxAttempts: 3,
    delay: (attempt, _) => Duration(milliseconds: 200 * (1 << (attempt - 1))),
    retryIf: (error) =>
        error is StashException && error.message.startsWith('Could not reach'),
  );

  /// Stable across rebuilds: the builder recreates its query whenever
  /// fetcher or variables change identity, which would drop an in-flight
  /// fetch back to idle. Reads live props at call time so a rebuild
  /// between mount and tap never fetches through stale objects.
  late final Signal<String> _link = signal(widget.entry.link!.trim());
  // Stored, not torn off per build: a fresh tear-off each build would read
  // as a new fetcher identity and recreate the query.
  // ignore: prefer_function_declarations_over_variables
  late final Future<Article> Function(String) _fetcher = (_) =>
      widget.service.fetchEntryArticle(widget.feed, widget.entry);

  @override
  void didUpdateWidget(covariant FeedEntryDownloadRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final link = widget.entry.link!.trim();
    if (link != _link.value) _link.value = link;
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  /// Downloads on tap, then opens or explains. Refetch never throws: the
  /// outcome lands on the query signals.
  Future<void> _read(
    BuildContext context,
    QueryView<Article, String> query,
  ) async {
    await query.refetch(_link.value);
    if (!context.mounted) return;
    final article = query.data.value;
    if (query.isSuccess.value && article != null) {
      widget.onOpen(widget.feed, widget.entry, article);
    } else if (query.isError.value) {
      final error = query.error.value;
      final message = error is StashException
          ? error.message
          : "Couldn't download this entry. Try again.";
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Article, String>(
      fetcher: _fetcher,
      variables: _link,
      autoFetch: false,
      retry: _retry,
      cacheKey: (link) => link.trim(),
      builder: (context, query) {
        final downloading = query.snapshot.value is AsyncValueLoading;
        return FeedEntryRow(
          entry: widget.entry,
          state: downloading
              ? EntryReadState.downloading
              : EntryReadState.downloadable,
          onRead: downloading ? () {} : () => _read(context, query),
        );
      },
    );
  }
}
