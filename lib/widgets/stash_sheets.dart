import 'package:flutter/material.dart';

import 'package:stashify/data/supported_sites.dart';
import 'package:stashify/models/stash_item.dart';
import 'package:stashify/utils/link_utils.dart';

Future<void> showSupportedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What stashes well',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const _SupportedRow(
              icon: Icons.rss_feed,
              title: 'RSS and Atom feeds',
              body: 'Any feed URL, including /feed and .xml links.',
            ),
            const SizedBox(height: 12),
            _SupportedRow(
              icon: Icons.article_outlined,
              title: 'Article pages',
              body: supportedArticleHosts.isEmpty
                  ? 'Not yet — no sites are supported.'
                  : 'These sites are supported: '
                      '${supportedArticleHosts.join(', ')}.',
            ),
          ],
        ),
      ),
    ),
  );
}

/// One entry of a stashed feed that cannot be read offline.
///
/// The entry's link points at a site with no article adapter, or it has no
/// link at all. The sheet names the problem instead of promising a read.
Future<void> showEntrySheet(BuildContext context, StashEntry entry) {
  final link = entry.link?.trim() ?? '';
  final domain = link.isEmpty ? '' : domainOf(link);
  final published = entryTime(entry.publishedAt);
  final meta = [
    if (domain.isNotEmpty) domain,
    if (published.isNotEmpty) published,
  ].join(' · ');
  final body =
      domain.isEmpty
          ? 'This entry has no link to download.'
          : 'Articles from $domain aren’t supported yet. Stashify can '
              'read articles from ${supportedArticleHosts.join(', ')}.';

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.title, style: theme.textTheme.headlineSmall),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meta,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(body, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showReaderSheet(BuildContext context, StashItem item) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Offline article',
                style: text.labelLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(item.title, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${item.domain} · saved ${timeAgo(item.savedAt)}'
                '${item.isFeed ? '' : ' · ${item.readMinutes} min read'}'
                ' · available offline',
                style: text.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'Mock article body for the UI pass. The first paragraphs, '
                'headings, and images will render here once fetching and '
                'parsing are wired up.',
                style: text.bodyLarge,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SupportedRow extends StatelessWidget {
  const _SupportedRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: scheme.onSecondaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              Text(body,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
