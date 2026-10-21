import 'package:flutter/material.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/utils/link_utils.dart';

class FeedEntryRow extends StatelessWidget {
  const FeedEntryRow({super.key, required this.entry, required this.onRead});

  final StashEntry entry;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final summary = entry.summary;
    final published = entryTime(entry.publishedAt);

    return InkWell(
      onTap: onRead,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    published,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRead,
                  style: TextButton.styleFrom(
                    // The label ends where the rule above it ends.
                    padding: const EdgeInsets.only(left: 12),
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Read'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
