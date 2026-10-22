import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:stashify/models/article.dart';

/// The offline article, set as calmly as the library allows.
///
/// A single centered column at a real reading measure. The app's settled
/// world owns the frame — the green-seeded Material 3 scheme, the M3 type
/// scale, 12–16px radii, hairline dividers, the offline-pin motif — and the
/// column itself stays quiet: body text, headings, code, lists, quotes and
/// images in the standard forms readers already know.
class ArticleView extends StatelessWidget {
  const ArticleView({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _Block(block: article.blocks[index]),
        childCount: article.blocks.length,
      ),
    );
  }
}

/// One [ArticleBlock] in the reading column.
class _Block extends StatelessWidget {
  const _Block({required this.block});

  final ArticleBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      ArticleHeading(:final level, :final text) => _Heading(
        level: level,
        text: text,
      ),
      ArticleParagraph(:final content) => _Paragraph(content: content),
      ArticleImage(:final url, :final alt) => _BodyImage(url: url, alt: alt),
      ArticleCode(:final code, :final language) => _CodeBlock(
        code: code,
        language: language,
      ),
      ArticleList(:final ordered, :final items) => _ArticleList(
        ordered: ordered,
        items: items,
      ),
      ArticleQuote(:final blocks) => _ArticleQuote(blocks: blocks),
    };
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.level, required this.text});

  final int level;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = switch (level) {
      1 => textTheme.headlineSmall,
      2 => textTheme.titleLarge,
      3 => textTheme.titleMedium,
      _ => textTheme.titleSmall,
    };

    // More space above a heading than below it, so sections read as
    // sections even at a large font scale.
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(header: true, child: Text(text, style: style)),
    );
  }
}

class _Paragraph extends StatefulWidget {
  const _Paragraph({required this.content});

  final List<ArticleInline> content;

  @override
  State<_Paragraph> createState() => _ParagraphState();
}

class _ParagraphState extends State<_Paragraph> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final tap in _taps) {
      tap.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _linkTap(String href) {
    final tap = TapGestureRecognizer()
      ..onTap = () {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('Links need a connection: $href')),
          );
      };
    _taps.add(tap);
    return tap;
  }

  @override
  Widget build(BuildContext context) {
    for (final tap in _taps) {
      tap.dispose();
    }
    _taps.clear();
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge;
    final codeStyle = body?.copyWith(
      fontFamily: 'monospace',
      backgroundColor: theme.colorScheme.secondaryContainer,
      color: theme.colorScheme.onSecondaryContainer,
    );
    final linkStyle = body?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text.rich(
        TextSpan(
          children: [
            for (final inline in widget.content)
              switch (inline) {
                ArticleText(:final text) => TextSpan(text: text, style: body),
                ArticleCodeSpan(:final code) => TextSpan(
                  text: code,
                  style: codeStyle,
                ),
                ArticleLink(:final text, :final href) => TextSpan(
                  text: text,
                  style: linkStyle,
                  // Offline the link goes nowhere; it stays recognisable
                  // as a link without pretending to open.
                  recognizer: _linkTap(href),
                ),
              },
          ],
        ),
      ),
    );
  }
}

class _BodyImage extends StatelessWidget {
  const _BodyImage({required this.url, this.alt});

  final String url;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _OfflineImage(url: url, alt: alt),
    );
  }
}

/// An image that degrades gracefully when the device is offline.
///
/// It tries the network image first and falls back to a muted box carrying
/// the alt text, so a missing cover or body image never breaks the column.
class _OfflineImage extends StatelessWidget {
  const _OfflineImage({required this.url, this.alt});

  final String url;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        semanticLabel: alt,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 180,
            color: scheme.surfaceContainerHigh,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        },
        errorBuilder: (context, _, _) {
          return Container(
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
                    alt == null || alt!.isEmpty
                        ? 'Image unavailable offline'
                        : alt!,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.offline_pin_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = language == null || language!.isEmpty ? null : language;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(
                label,
                style: text.labelSmall?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 8),
            ],
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleList extends StatelessWidget {
  const _ArticleList({required this.ordered, required this.items});

  final bool ordered;
  final List<ArticleListItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: ordered
                        ? Text(
                            '${i + 1}.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                  ),
                  Expanded(child: _InlineText(content: items[i].content)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline runs outside a paragraph: list items share the same vocabulary.
class _InlineText extends StatelessWidget {
  const _InlineText({required this.content});

  final List<ArticleInline> content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge;
    final codeStyle = body?.copyWith(
      fontFamily: 'monospace',
      backgroundColor: theme.colorScheme.secondaryContainer,
      color: theme.colorScheme.onSecondaryContainer,
    );
    final linkStyle = body?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    return Text.rich(
      TextSpan(
        children: [
          for (final inline in content)
            switch (inline) {
              ArticleText(:final text) => TextSpan(text: text, style: body),
              ArticleCodeSpan(:final code) => TextSpan(
                text: code,
                style: codeStyle,
              ),
              ArticleLink(:final text) => TextSpan(
                text: text,
                style: linkStyle,
              ),
            },
        ],
      ),
    );
  }
}

class _ArticleQuote extends StatelessWidget {
  const _ArticleQuote({required this.blocks});

  final List<ArticleBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote, color: scheme.primary),
            for (final block in blocks) _Block(block: block),
          ],
        ),
      ),
    );
  }
}
