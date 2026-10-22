import 'package:flutter/material.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/utils/link_utils.dart';

/// What the row's footer offers for one entry.
enum EntryReadState {
  /// The entry can be downloaded: Read fetches it, then opens it.
  downloadable,

  /// The download is running: the control holds progress, not a tap.
  downloading,

  /// The body is cached: Read opens it with the offline mark beside it.
  downloaded,

  /// The entry opens its live page in the app browser instead.
  browser,

  /// The entry has no openable link: the row says so instead of Read.
  unsupported,
}

class FeedEntryRow extends StatelessWidget {
  const FeedEntryRow({
    super.key,
    required this.entry,
    required this.onRead,
    this.state = EntryReadState.downloadable,
  });

  final StashEntry entry;
  final VoidCallback onRead;
  final EntryReadState state;

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
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: _Action(state: state, onRead: onRead),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single control per entry: Read, its progress, its offline mark, or
/// the honest word when there is nothing to download.
class _Action extends StatelessWidget {
  const _Action({required this.state, required this.onRead});

  final EntryReadState state;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (state) {
      case EntryReadState.downloading:
        return TextButton(
          onPressed: null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 12),
            minimumSize: const Size(48, 48),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Downloading…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      case EntryReadState.downloaded:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.offline_pin_outlined, size: 18, color: scheme.primary),
            TextButton(
              onPressed: onRead,
              style: TextButton.styleFrom(
                // The label ends where the rule above it ends.
                padding: const EdgeInsets.only(left: 8),
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Read'),
            ),
          ],
        );
      case EntryReadState.unsupported:
        return TextButton(
          onPressed: onRead,
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            padding: const EdgeInsets.only(left: 12),
            minimumSize: const Size(48, 48),
          ),
          child: const Text(
            'Not supported',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      case EntryReadState.downloadable || EntryReadState.browser:
        return TextButton(onPressed: onRead, child: const Text('Read'));
    }
  }
}
