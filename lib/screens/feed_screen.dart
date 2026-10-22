import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:stashify/models/article.dart';
import 'package:stashify/models/stash_item.dart';
import 'package:stashify/screens/reader_screen.dart';
import 'package:stashify/services/stash_service.dart';
import 'package:stashify/utils/browser.dart';
import 'package:stashify/utils/link_utils.dart';
import 'package:stashify/widgets/empty_state.dart';
import 'package:stashify/widgets/feed_entry_download_row.dart';
import 'package:stashify/widgets/feed_entry_row.dart';
import 'package:stashify/widgets/stash_sheets.dart';

/// Opens [url] in the app browser.
///
/// A hook rather than a direct call so widget tests can record the routing
/// without touching platform channels.
typedef OpenBrowser = void Function(BuildContext context, Uri url);

/// Whether the live page can be reached.
///
/// A hook so widget tests can answer without the platform plugin. A check
/// that itself fails must not block reading.
Future<bool> _checkOnline() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  } catch (_) {
    return true;
  }
}

/// The entries of a stashed feed.
///
/// Each row carries one control. A downloadable entry fetches on the first
/// tap and opens after it; a cached entry opens at once with the offline
/// mark beside its Read; any other linked entry opens its live page in the
/// app browser; an entry with no openable link says so instead of
/// promising a read.
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.feed,
    required this.service,
    this.openBrowser = openLivePage,
    this.isOnline = _checkOnline,
  });

  final StashItem feed;
  final StashService service;

  /// Opens a live page. Tests inject a recorder here.
  final OpenBrowser openBrowser;

  /// Answers connectivity. Tests inject a fixed answer here.
  final Future<bool> Function() isOnline;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  StashItem _current(List<StashItem> items) {
    for (final item in items) {
      if (item.id == widget.feed.id) return item;
    }
    return widget.feed;
  }

  EntryReadState _stateOf(StashEntry entry) {
    if (entry.article != null) return EntryReadState.downloaded;
    final link = entry.link?.trim() ?? '';
    final uri = Uri.tryParse(link);
    final openable =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!openable) return EntryReadState.unsupported;
    if (isSupportedArticleHost(link)) return EntryReadState.downloadable;
    return EntryReadState.browser;
  }

  Future<void> _onRead(StashItem feed, StashEntry entry) async {
    switch (_stateOf(entry)) {
      case EntryReadState.downloaded:
        _openArticle(feed, entry, entry.article!);
      case EntryReadState.downloading:
        break;
      case EntryReadState.browser:
        final uri = Uri.parse(entry.link!.trim());
        if (!await widget.isOnline()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Needs a connection to open the live page.'),
              ),
            );
          return;
        }
        if (!mounted) return;
        widget.openBrowser(context, uri);
      case EntryReadState.unsupported:
        showEntrySheet(context, entry);
      case EntryReadState.downloadable:
        // Runs inside a FeedEntryDownloadRow, which owns the fetch.
        break;
    }
  }

  void _openArticle(StashItem feed, StashEntry entry, Article article) {
    final link = entry.link!.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ReaderScreen(
              item: StashItem(
                id: '${feed.id}:${entry.link}',
                url: link,
                title: entry.title,
                domain: domainOf(link),
                savedAt: feed.savedAt,
                readMinutes: article.readMinutes,
                article: article,
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final titleStyle = text.titleLarge!;
    final metaStyle = text.bodySmall!;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final titleHeight =
        titleStyle.fontSize! * (titleStyle.height ?? 1.33) * scale;
    final metaHeight = metaStyle.fontSize! * (metaStyle.height ?? 1.33) * scale;

    return Scaffold(
      appBar: AppBar(
        // The bar grows with the text, so a large font scale does not
        // overflow it.
        toolbarHeight: titleHeight + metaHeight + 16,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.feed.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            SignalBuilder(
              builder: (context) {
                final feed = _current(widget.service.items.value);
                return Text(
                  '${feed.entries.length} ${feed.entries.length == 1 ? 'entry' : 'entries'}'
                  ' · ${feed.domain}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle.copyWith(color: scheme.onSurfaceVariant),
                );
              },
            ),
          ],
        ),
      ),
      body: SignalBuilder(
        builder: (context) {
          final feed = _current(widget.service.items.value);
          final entries = feed.entries;
          return entries.isEmpty
              ? const EmptyState(
                icon: Icons.rss_feed,
                title: 'Nothing in this feed',
                body: 'There was nothing in it when it was stashed.',
              )
              : ListView.separated(
                padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  if (_stateOf(entry) == EntryReadState.downloadable) {
                    return FeedEntryDownloadRow(
                      key: ValueKey('download:${entry.link}'),
                      feed: feed,
                      entry: entry,
                      service: widget.service,
                      onOpen: _openArticle,
                    );
                  }
                  return FeedEntryRow(
                    entry: entry,
                    state: _stateOf(entry),
                    onRead: () => _onRead(feed, entry),
                  );
                },
              );
        },
      ),
    );
  }
}
