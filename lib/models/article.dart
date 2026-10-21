/// A parsed article, ready to be rendered by the UI.
///
/// Adapters build this from a site's HTML. The shape is deliberately small:
/// a flat list of [ArticleBlock]s in reading order, with [ArticleInline]s
/// inside the blocks that carry text. It holds no Flutter types, so it can
/// be built and tested without a widget tree.
class Article {
  const Article({
    required this.title,
    this.coverImageUrl,
    this.blocks = const [],
  });

  /// The headline of the article.
  final String title;

  /// The cover image, when the page has one.
  final String? coverImageUrl;

  /// The body, in reading order.
  final List<ArticleBlock> blocks;

  /// A rough reading time, at 200 words a minute and never under a minute.
  int get readMinutes {
    final words = _wordCountIn(blocks);
    return words == 0 ? 1 : (words / 200).ceil();
  }
}

/// One block of an article body.
sealed class ArticleBlock {
  const ArticleBlock();
}

/// A section heading, with [level] 1 for the top level.
class ArticleHeading extends ArticleBlock {
  const ArticleHeading({required this.level, required this.text});

  final int level;
  final String text;
}

/// A paragraph of text.
class ArticleParagraph extends ArticleBlock {
  const ArticleParagraph(this.content);

  final List<ArticleInline> content;
}

/// An image between blocks.
class ArticleImage extends ArticleBlock {
  const ArticleImage({required this.url, this.alt});

  final String url;
  final String? alt;
}

/// A block of source code.
class ArticleCode extends ArticleBlock {
  const ArticleCode({required this.code, this.language});

  final String code;

  /// The language the page labelled the block with, when it did.
  final String? language;
}

/// A bullet or numbered list.
class ArticleList extends ArticleBlock {
  const ArticleList({required this.ordered, required this.items});

  final bool ordered;
  final List<ArticleListItem> items;
}

/// One item of an [ArticleList].
class ArticleListItem {
  const ArticleListItem(this.content);

  final List<ArticleInline> content;
}

/// A quotation, with its own blocks.
class ArticleQuote extends ArticleBlock {
  const ArticleQuote(this.blocks);

  final List<ArticleBlock> blocks;
}

/// A run of text inside a block.
sealed class ArticleInline {
  const ArticleInline();

  /// The run as plain text, ignoring its formatting.
  String get text;
}

/// Plain text.
class ArticleText extends ArticleInline {
  const ArticleText(this.text);

  @override
  final String text;
}

/// A code span inside running text.
class ArticleCodeSpan extends ArticleInline {
  const ArticleCodeSpan(this.code);

  final String code;

  @override
  String get text => code;
}

/// A link inside running text.
class ArticleLink extends ArticleInline {
  const ArticleLink({required this.text, required this.href});

  @override
  final String text;

  /// The absolute target of the link.
  final String href;
}

int _wordCountIn(Iterable<ArticleBlock> blocks) {
  var words = 0;
  for (final block in blocks) {
    switch (block) {
      case ArticleHeading(:final text):
        words += _wordsIn(text);
      case ArticleParagraph(:final content):
        words += _wordsIn(_textOf(content));
      case ArticleImage():
        break;
      case ArticleCode(:final code):
        words += _wordsIn(code);
      case ArticleList(:final items):
        for (final item in items) {
          words += _wordsIn(_textOf(item.content));
        }
      case ArticleQuote(:final blocks):
        words += _wordCountIn(blocks);
    }
  }
  return words;
}

String _textOf(Iterable<ArticleInline> inlines) =>
    inlines.map((inline) => inline.text).join(' ');

int _wordsIn(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
}
