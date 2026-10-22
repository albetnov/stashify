// The article codec: every block and inline kind survives storage,
// and hostile input degrades to skips and nulls instead of throwing.
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/data/article_codec.dart';
import 'package:stashify/models/article.dart';

Article _article() => const Article(
  title: 'Fast validators',
  coverImageUrl: 'https://example.com/cover.jpg',
  blocks: [
    ArticleHeading(level: 2, text: 'Summary'),
    ArticleParagraph([
      ArticleText('One pass beats two. '),
      ArticleLink(text: 'Read more', href: 'https://example.com/more'),
      ArticleCodeSpan('O(n)'),
    ]),
    ArticleImage(url: 'https://example.com/pic.png', alt: 'A picture'),
    ArticleCode(code: 'print(1)', language: 'dart'),
    ArticleList(
      ordered: true,
      items: [
        ArticleListItem([ArticleText('First')]),
        ArticleListItem([ArticleText('Second')]),
      ],
    ),
    ArticleQuote([
      ArticleParagraph([ArticleText('Quoted.')]),
    ]),
  ],
);

void _expectSame(Article actual, Article expected) {
  expect(actual.title, expected.title);
  expect(actual.coverImageUrl, expected.coverImageUrl);
  expect(actual.blocks.length, expected.blocks.length);
  expect(actual.blocks[0], isA<ArticleHeading>());
  expect((actual.blocks[1] as ArticleParagraph).content.map((e) => e.text), [
    'One pass beats two. ',
    'Read more',
    'O(n)',
  ]);
  expect((actual.blocks[1] as ArticleParagraph).content[1], isA<ArticleLink>());
  expect(actual.blocks[2], isA<ArticleImage>());
  expect((actual.blocks[3] as ArticleCode).language, 'dart');
  expect((actual.blocks[4] as ArticleList).ordered, isTrue);
  expect((actual.blocks[4] as ArticleList).items, hasLength(2));
  expect(
    ((actual.blocks[5] as ArticleQuote).blocks.single as ArticleParagraph)
        .content
        .single
        .text,
    'Quoted.',
  );
}

void main() {
  test('every block and inline kind round-trips', () {
    final article = _article();

    final decoded = ArticleCodec.tryDecodeString(
      ArticleCodec.encodeString(article),
    );

    expect(decoded, isNotNull);
    _expectSame(decoded!, article);
  });

  test('a round-trip is byte-stable', () {
    final once = ArticleCodec.encodeString(_article());
    final twice = ArticleCodec.encodeString(
      ArticleCodec.tryDecodeString(once)!,
    );

    expect(twice, once);
  });

  test('unknown kinds are skipped, not fatal', () {
    final decoded = ArticleCodec.tryDecodeString(
      '{"title":"T","blocks":['
      '{"type":"poll","options":[]},'
      '{"type":"paragraph","content":[{"type":"mention","user":"ada"},{"type":"text","text":"Hi"}]},'
      '{"type":"heading","text":"Kept"}'
      ']}',
    );

    expect(decoded, isNotNull);
    expect(decoded!.blocks, hasLength(2));
    expect(
      (decoded.blocks.first as ArticleParagraph).content.single.text,
      'Hi',
    );
  });

  test('missing keys fall back to defaults', () {
    final decoded = ArticleCodec.tryDecodeString('{"blocks":[{}]}');

    expect(decoded, isNotNull);
    expect(decoded!.title, isEmpty);
    expect(decoded.blocks, isEmpty);
  });

  test('garbage and empty input decode to null', () {
    expect(ArticleCodec.tryDecodeString(null), isNull);
    expect(ArticleCodec.tryDecodeString(''), isNull);
    expect(ArticleCodec.tryDecodeString('not json'), isNull);
    expect(ArticleCodec.tryDecodeString('[1,2]'), isNull);
  });
}
