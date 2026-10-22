import 'package:flutter/material.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/utils/link_utils.dart';

class StashRow extends StatelessWidget {
  const StashRow({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDelete,
  });

  final StashItem item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isFeed ? Icons.rss_feed : Icons.article_outlined,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${item.domain} · Saved ${timeAgo(item.savedAt)}'
                      '${item.isFeed ? '' : ' · ${item.readMinutes} min'}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.isFeed || item.article != null)
                Icon(Icons.offline_pin_outlined, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
