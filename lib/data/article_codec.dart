import 'dart:convert';

import 'package:stashify/models/article.dart';

/// Codec between [Article] trees and the JSON stored in `article_json`.
///
/// Decode is lenient on purpose: rows outlive code deploys, so an unknown
/// block or inline kind is skipped and missing keys fall back to defaults
/// instead of failing the whole library load.
abstract final class ArticleCodec {
  /// Encodes [article] to a JSON string for storage.
  static String encodeString(Article article) =>
      jsonEncode(_encodeArticle(article));

  /// Decodes a stored body, or `null` when there is nothing to decode.
  ///
  /// Garbage input also decodes to `null`: the entry keeps listing, it
  /// just has no body to open.
  static Article? tryDecodeString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return _decodeArticle(decoded);
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _encodeArticle(Article article) => {
    'title': article.title,
    'cover': article.coverImageUrl,
    'blocks': [for (final block in article.blocks) _encodeBlock(block)],
  };

  static Article _decodeArticle(Map<String, Object?> json) => Article(
    title: _string(json, 'title'),
    coverImageUrl: _stringOrNull(json, 'cover'),
    blocks: _decodeBlocks(json['blocks']),
  );

  static Map<String, Object?> _encodeBlock(ArticleBlock block) => switch (block) {
    ArticleHeading(:final level, :final text) => {
      'type': 'heading',
      'level': level,
      'text': text,
    },
    ArticleParagraph(:final content) => {
      'type': 'paragraph',
      'content': [for (final inline in content) _encodeInline(inline)],
    },
    ArticleImage(:final url, :final alt) => {
      'type': 'image',
      'url': url,
      'alt': alt,
    },
    ArticleCode(:final code, :final language) => {
      'type': 'code',
      'code': code,
      'language': language,
    },
    ArticleList(:final ordered, :final items) => {
      'type': 'list',
      'ordered': ordered,
      'items': [
        for (final item in items)
          [for (final inline in item.content) _encodeInline(inline)],
      ],
    },
    ArticleQuote(:final blocks) => {
      'type': 'quote',
      'blocks': [for (final inner in blocks) _encodeBlock(inner)],
    },
  };

  static ArticleBlock? _decodeBlock(Map<String, Object?> json) {
    switch (json['type']) {
      case 'heading':
        return ArticleHeading(
          level: _int(json, 'level', fallback: 1),
          text: _string(json, 'text'),
        );
      case 'paragraph':
        return ArticleParagraph(_decodeInlines(json, 'content'));
      case 'image':
        final url = _stringOrNull(json, 'url');
        if (url == null) return null;
        return ArticleImage(url: url, alt: _stringOrNull(json, 'alt'));
      case 'code':
        return ArticleCode(
          code: _string(json, 'code'),
          language: _stringOrNull(json, 'language'),
        );
      case 'list':
        return ArticleList(
          ordered: _bool(json, 'ordered'),
          items: [
            for (final raw in _list(json, 'items'))
              if (raw is List) ArticleListItem(_decodeInlineList(raw)),
          ],
        );
      case 'quote':
        return ArticleQuote(_decodeBlocks(json['blocks']));
      default:
        return null;
    }
  }

  static List<ArticleBlock> _decodeBlocks(Object? raw) {
    final blocks = <ArticleBlock>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, Object?>) {
          final block = _decodeBlock(item);
          if (block != null) blocks.add(block);
        }
      }
    }
    return blocks;
  }

  static Map<String, Object?> _encodeInline(ArticleInline inline) =>
      switch (inline) {
        ArticleText(:final text) => {'type': 'text', 'text': text},
        ArticleCodeSpan(:final code) => {'type': 'code', 'code': code},
        ArticleLink(:final text, :final href) => {
          'type': 'link',
          'text': text,
          'href': href,
        },
      };

  static ArticleInline? _decodeInline(Map<String, Object?> json) {
    switch (json['type']) {
      case 'text':
        return ArticleText(_string(json, 'text'));
      case 'code':
        return ArticleCodeSpan(_string(json, 'code'));
      case 'link':
        return ArticleLink(
          text: _string(json, 'text'),
          href: _string(json, 'href'),
        );
      default:
        return null;
    }
  }

  static List<ArticleInline> _decodeInlines(
    Map<String, Object?> json,
    String key,
  ) {
    final raw = json[key];
    return raw is List ? _decodeInlineList(raw) : const [];
  }

  static List<ArticleInline> _decodeInlineList(List<Object?> raw) {
    final inlines = <ArticleInline>[];
    for (final item in raw) {
      if (item is Map<String, Object?>) {
        final inline = _decodeInline(item);
        if (inline != null) inlines.add(inline);
      }
    }
    return inlines;
  }

  static String _string(Map<String, Object?> json, String key) =>
      json[key] is String ? json[key] as String : '';

  static String? _stringOrNull(Map<String, Object?> json, String key) =>
      json[key] is String ? json[key] as String : null;

  static int _int(Map<String, Object?> json, String key, {int fallback = 0}) =>
      json[key] is int ? json[key] as int : fallback;

  static bool _bool(Map<String, Object?> json, String key) =>
      json[key] == true;

  static List<Object?> _list(Map<String, Object?> json, String key) =>
      json[key] is List ? (json[key] as List).cast<Object?>() : const [];
}
