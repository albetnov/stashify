import 'package:flutter/material.dart';

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
  bool _downloading = false;

  Future<void> _read(BuildContext context) async {
    setState(() => _downloading = true);
    try {
      final article = await widget.service.fetchEntryArticle(
        widget.feed,
        widget.entry,
      );
      if (!context.mounted) return;
      widget.onOpen(widget.feed, widget.entry, article);
    } catch (error) {
      if (!context.mounted) return;
      final message = error is StashException
          ? error.message
          : "Couldn't download this entry. Try again.";
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeedEntryRow(
      entry: widget.entry,
      state: _downloading
          ? EntryReadState.downloading
          : EntryReadState.downloadable,
      onRead: _downloading ? () {} : () => _read(context),
    );
  }
}