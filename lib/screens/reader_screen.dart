import 'package:flutter/material.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/utils/link_utils.dart';
import 'package:stashify/widgets/article_view.dart';
import 'package:stashify/widgets/empty_state.dart';

/// The offline article, on its own route.
///
/// The visitor stashed a page while online and opens it to read with no
/// connection. The app bar carries only where the reader is — the domain
/// and the offline mark — and the column carries everything else: the
/// title, the saved line, the cover, then the body in reading order.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.item});

  final StashItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final article = item.article;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.domain, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.offline_pin_outlined),
          ),
        ],
      ),
      body: article == null
          ? const EmptyState(
              icon: Icons.article_outlined,
              title: 'Nothing readable here',
              body:
                  'This page was stashed before article parsing '
                  'was ready.',
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(article.title, style: text.headlineSmall),
                              const SizedBox(height: 8),
                              Text(
                                '${timeAgo(item.savedAt)}'
                                ' · ${item.readMinutes} min read'
                                ' · available offline',
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Divider(
                                height: 25,
                                thickness: 1,
                                color: scheme.outlineVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (article.coverImageUrl != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                article.coverImageUrl!,
                                fit: BoxFit.cover,
                                semanticLabel: 'Cover image',
                                errorBuilder: (context, _, _) => Container(
                                  padding: const EdgeInsets.all(16),
                                  color: scheme.surfaceContainerHigh,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Cover unavailable offline',
                                          style: text.bodyMedium?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        sliver: ArticleView(article: article),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
