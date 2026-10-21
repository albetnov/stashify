import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import 'package:stashify/models/article.dart';
import 'package:stashify/services/article_adapter.dart';

/// The site's article template puts the cover image in the page header and
/// the body in `#blog-content`. The body is MDX rendered to plain HTML, so
/// headings, paragraphs, lists, code blocks and quotes map one to one. Every
/// image in the body becomes an [ArticleImage] block in the order it appears.
class AlbetnvAdapter implements ArticleAdapter {
  const AlbetnvAdapter();

  /// The site this adapter reads. Subdomains are covered too.
  static const host = 'albetnv.dev';

  @override
  bool handles(Uri uri) {
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    return host == AlbetnvAdapter.host ||
        host.endsWith('.${AlbetnvAdapter.host}');
  }

  @override
  Article parse(String htmlText, {required Uri uri}) {
    final document = html.parse(_unwrapped(htmlText));

    final body = document.querySelector('#blog-content');
    final blocks = body == null ? const <ArticleBlock>[] : _blocksOf(body, uri);
    if (blocks.isEmpty) {
      throw const ArticleParseException('That page has no readable article.');
    }

    return Article(
      title: _titleOf(document, uri),
      coverImageUrl: _coverOf(document, uri),
      blocks: blocks,
    );
  }

  /// Browsers save a `view-source:` page as a table of escaped source lines.
  /// The text of its cells is the real document, so join it back together
  /// before parsing. A normal page passes through untouched.
  static String _unwrapped(String htmlText) {
    if (!htmlText.contains('line-content')) return htmlText;

    final outer = html.parse(htmlText);
    final lines = outer.querySelectorAll('td.line-content');
    if (lines.isEmpty) return htmlText;
    return lines.map((line) => line.text).join('\n');
  }

  static String _titleOf(dom.Document document, Uri uri) {
    final heading =
        document.querySelector('article header h1') ??
        document.querySelector('header h1');
    final headline = _clean(heading?.text ?? '');
    if (headline.isNotEmpty) return headline;

    // The site suffixes the page title with the name of its log.
    final title = _clean(document.querySelector('title')?.text ?? '');
    final cut = title.lastIndexOf(' | ');
    final pageTitle = cut == -1 ? title : title.substring(0, cut).trim();
    return pageTitle.isNotEmpty ? pageTitle : uri.host;
  }

  static String? _coverOf(dom.Document document, Uri uri) {
    return _imageUrl(
      document.querySelector('header')?.querySelector('img'),
      uri,
    );
  }

  static String? _imageUrl(dom.Element? image, Uri page) {
    final src =
        (image?.attributes['src'] ?? image?.attributes['data-src'] ?? '')
            .trim();
    return src.isEmpty ? null : page.resolve(src).toString();
  }

  static List<ArticleBlock> _blocksOf(dom.Element parent, Uri page) {
    final blocks = <ArticleBlock>[];
    for (final node in parent.nodes) {
      _addBlock(node, blocks, page);
    }
    return blocks;
  }

  static void _addBlock(dom.Node node, List<ArticleBlock> blocks, Uri page) {
    if (node is! dom.Element) return;

    switch (node.localName) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final text = _clean(node.text);
        if (text.isNotEmpty) {
          final level = int.parse(node.localName![1]);
          blocks.add(ArticleHeading(level: level, text: text));
        }
      case 'p':
        _addParagraph(node, blocks, page);
      case 'img':
        _addImage(node, blocks, page);
      case 'ul' || 'ol':
        _addList(node, blocks, page);
      case 'pre':
        _addCode(node, blocks);
      case 'blockquote':
        final quote = _blocksOf(node, page);
        if (quote.isNotEmpty) blocks.add(ArticleQuote(quote));
      case 'script' || 'style' || 'noscript':
        break;
      default:
        // Containers such as figure, section and div keep their order; a
        // container that only holds text is still worth reading.
        final before = blocks.length;
        for (final child in node.nodes) {
          _addBlock(child, blocks, page);
        }
        if (blocks.length == before) {
          _addParagraph(node, blocks, page);
        }
    }
  }

  static void _addParagraph(
    dom.Element paragraph,
    List<ArticleBlock> blocks,
    Uri page,
  ) {
    var inlines = <ArticleInline>[];

    void flush() {
      final content = _tidy(inlines);
      if (content.isNotEmpty) blocks.add(ArticleParagraph(content));
      inlines = <ArticleInline>[];
    }

    void add(dom.Node node) {
      _addInline(
        node,
        inlines,
        page,
        onImage: (image) {
          flush();
          _addImage(image, blocks, page);
        },
      );
    }

    for (final node in paragraph.nodes) {
      add(node);
    }
    flush();
  }

  static void _addImage(
    dom.Element image,
    List<ArticleBlock> blocks,
    Uri page,
  ) {
    final url = _imageUrl(image, page);
    if (url == null) return;

    final alt = _clean(image.attributes['alt'] ?? '');
    blocks.add(ArticleImage(url: url, alt: alt.isEmpty ? null : alt));
  }

  static void _addList(dom.Element list, List<ArticleBlock> blocks, Uri page) {
    final items = <ArticleListItem>[];
    for (final item in list.children) {
      if (item.localName != 'li') continue;
      final content = _inlinesOf(item, page);
      if (content.isNotEmpty) items.add(ArticleListItem(content));
    }
    if (items.isNotEmpty) {
      blocks.add(ArticleList(ordered: list.localName == 'ol', items: items));
    }
  }

  static void _addCode(dom.Element pre, List<ArticleBlock> blocks) {
    final code = pre.querySelector('code') ?? pre;
    final text = code.text.replaceFirst(RegExp(r'^\n+'), '');
    final body = text.replaceFirst(RegExp(r'\s+$'), '');
    if (body.isEmpty) return;

    final language = _clean(
      pre.attributes['data-language'] ??
          _languageOf(pre) ??
          _languageOf(code) ??
          '',
    );
    blocks.add(
      ArticleCode(code: body, language: language.isEmpty ? null : language),
    );
  }

  static String? _languageOf(dom.Element element) {
    for (final name in element.className.split(RegExp(r'\s+'))) {
      if (name.startsWith('language-')) return name.substring(9);
    }
    return null;
  }

  static List<ArticleInline> _inlinesOf(dom.Element element, Uri page) {
    final inlines = <ArticleInline>[];
    for (final node in element.nodes) {
      _addInline(node, inlines, page);
    }
    return _tidy(inlines);
  }

  static void _addInline(
    dom.Node node,
    List<ArticleInline> inlines,
    Uri page, {
    void Function(dom.Element image)? onImage,
  }) {
    if (node is dom.Text) {
      final text = _collapse(node.text);
      if (text.isNotEmpty) inlines.add(ArticleText(text));
      return;
    }
    if (node is! dom.Element) return;

    switch (node.localName) {
      case 'code':
        final code = _clean(node.text);
        if (code.isNotEmpty) inlines.add(ArticleCodeSpan(code));
      case 'a':
        final href = node.attributes['href']?.trim();
        final text = _clean(node.text);
        if (href == null || href.isEmpty || text.isEmpty) {
          for (final child in node.nodes) {
            _addInline(child, inlines, page, onImage: onImage);
          }
        } else {
          inlines.add(
            ArticleLink(text: text, href: page.resolve(href).toString()),
          );
        }
      case 'br':
        inlines.add(const ArticleText(' '));
      case 'img':
        onImage?.call(node);
      case 'script' || 'style' || 'noscript':
        break;
      default:
        for (final child in node.nodes) {
          _addInline(child, inlines, page, onImage: onImage);
        }
    }
  }

  /// Collapses runs of source whitespace, which HTML ignores anyway.
  static String _collapse(String text) => text.replaceAll(RegExp(r'\s+'), ' ');

  static String _clean(String text) => _collapse(text).trim();

  /// Merges adjacent text runs and trims the ends of the block, keeping the
  /// spaces that sit between a text run and the next inline node.
  static List<ArticleInline> _tidy(List<ArticleInline> raw) {
    final inlines = <ArticleInline>[];
    for (final inline in raw) {
      if (inline is ArticleText && inline.text.isEmpty) continue;
      if (inline is ArticleText &&
          inlines.isNotEmpty &&
          inlines.last is ArticleText) {
        final previous = inlines.removeLast() as ArticleText;
        inlines.add(ArticleText(previous.text + inline.text));
      } else {
        inlines.add(inline);
      }
    }

    if (inlines.isNotEmpty && inlines.first is ArticleText) {
      final trimmed = (inlines.first as ArticleText).text.trimLeft();
      if (trimmed.isEmpty) {
        inlines.removeAt(0);
      } else {
        inlines[0] = ArticleText(trimmed);
      }
    }

    if (inlines.isNotEmpty && inlines.last is ArticleText) {
      final trimmed = (inlines.last as ArticleText).text.trimRight();
      inlines.removeLast();
      if (trimmed.isNotEmpty) inlines.add(ArticleText(trimmed));
    }

    return inlines;
  }
}
