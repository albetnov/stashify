import 'package:flutter/material.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/widgets/empty_state.dart';
import 'package:stashify/widgets/feed_entry_row.dart';
import 'package:stashify/widgets/stash_sheets.dart';

/// The entries of a stashed feed.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key, required this.feed});

  final StashItem feed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final entries = feed.entries;

    final titleStyle = text.titleLarge!;
    final metaStyle = text.bodySmall!;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final titleHeight =
        titleStyle.fontSize! * (titleStyle.height ?? 1.33) * scale;
    final metaHeight =
        metaStyle.fontSize! * (metaStyle.height ?? 1.33) * scale;

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
              feed.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}'
              ' · ${feed.domain}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metaStyle.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: entries.isEmpty
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
                return FeedEntryRow(
                  entry: entry,
                  onRead: () => showEntrySheet(context, entry),
                );
              },
            ),
    );
  }
}
