// The albetnv.dev adapter: the saved page, and the edges around it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/models/article.dart';
import 'package:stashify/services/albetnv_adapter.dart';
import 'package:stashify/services/article_adapter.dart';

void main() {
  const adapter = AlbetnvAdapter();
  final page = Uri.parse(
    'https://albetnv.dev/blog/'
    'validasi-v1-rc-released-with-performance-improvement/',
  );

  test('the adapter covers albetnv.dev and its subdomains', () {
    expect(adapter.handles(Uri.parse('https://albetnv.dev/blog/x')), isTrue);
    expect(
      adapter.handles(Uri.parse('https://www.albetnv.dev/blog/x')),
      isTrue,
    );
    expect(adapter.handles(Uri.parse('https://notes.albetnv.dev/x')), isTrue);
    expect(adapter.handles(Uri.parse('https://evil-albetnv.dev/x')), isFalse);
    expect(adapter.handles(Uri.parse('https://example.com/x')), isFalse);
  });

  group('the saved page', () {
    late Article article;

    setUpAll(() {
      final golden = File('test/fixtures/golden.html').readAsStringSync();
      article = adapter.parse(golden, uri: page);
    });

    test('takes the header image as the cover', () {
      expect(
        article.coverImageUrl,
        'https://res.cloudinary.com/dltzvdmck/image/upload/'
        'c_limit,w_1200/f_auto/q_auto/v1/blogs/'
        'validasi-rc-performance_mw5gq9?_a=BBGAGRGX0',
      );
    });

    test('takes the headline from the page header', () {
      expect(
        article.title,
        'From O(N²) to O(N): The Performance Deep-Dive That Made Validasi '
        'Faster and Simpler',
      );
    });

    test('keeps the body blocks in reading order', () {
      final first = article.blocks.first;
      expect(first, isA<ArticleHeading>());
      expect((first as ArticleHeading).level, 2);
      expect(first.text, 'Summary');
      expect(article.blocks[1], isA<ArticleParagraph>());

      final headings = article.blocks
          .whereType<ArticleHeading>()
          .map((heading) => heading.text)
          .toList();
      expect(headings.take(3), ['Summary', 'Key changes:', 'Outcome:']);
      expect(headings.last, 'Closing');
    });

    test('reads lists, code blocks, and the quote', () {
      final lists = article.blocks.whereType<ArticleList>().toList();
      expect(lists, isNotEmpty);
      expect(lists.first.ordered, isFalse);
      expect(lists.first.items, hasLength(5));
      expect(
        _text(lists.first.items.first.content),
        'Replaced quadratic uniqueness checks with HashSet-based tracking',
      );

      final code = article.blocks.whereType<ArticleCode>().toList();
      expect(code, isNotEmpty);
      expect(code.first.language, 'dart');
      expect(code.first.code, contains('final seen = <T>[];'));
      expect(code.first.code, startsWith('final seen'));
      expect(code.first.code, isNot(endsWith('\n')));

      final quote = article.blocks.whereType<ArticleQuote>().single;
      final quoted = quote.blocks.single as ArticleParagraph;
      expect(
        _text(quoted.content),
        'The system is used on every validation path. That makes CPU '
        'efficiency matters more than theoretical purity.',
      );
    });

    test('turns inline code into its own run', () {
      final paragraph = article.blocks.whereType<ArticleParagraph>().firstWhere(
        (paragraph) =>
            paragraph.content.any((inline) => inline is ArticleCodeSpan),
      );

      final spans = paragraph.content.whereType<ArticleCodeSpan>();
      expect(spans.single.code, 'Unique');
    });

    test('finds no body image in this page, and does not invent one', () {
      expect(article.blocks.whereType<ArticleImage>(), isEmpty);
    });

    test('estimates a reading time', () {
      expect(article.readMinutes, greaterThan(1));
    });
  });

  group('a body with images', () {
    late Article article;

    setUpAll(() {
      article = adapter.parse('''
<html><head><title>A log entry | Phantom Log</title></head>
<body><article>
<header><img src="/cover.jpg" alt="Cover"></header>
<div id="blog-content">
  <p>Before the first image.</p>
  <img src="first.png" alt="First">
  <p>Between the images.</p>
  <img src="https://cdn.example.com/second.png">
  <p>After <img src="inline.png"> the last.</p>
</div>
</article></body></html>
''', uri: page);
    });

    test('keeps every image in the order it appears', () {
      final layout = article.blocks
          .map(
            (block) => switch (block) {
              ArticleImage() => 'image',
              ArticleParagraph() => 'text',
              _ => 'other',
            },
          )
          .join(' ');

      expect(layout, 'text image text image text image text');
    });

    test('resolves image sources against the page', () {
      final images = article.blocks.whereType<ArticleImage>().toList();
      expect(images.map((image) => image.url), [
        page.resolve('first.png').toString(),
        'https://cdn.example.com/second.png',
        page.resolve('inline.png').toString(),
      ]);
      expect(images.first.alt, 'First');
      expect(images[1].alt, isNull);
    });

    test('keeps the cover out of the body', () {
      expect(article.coverImageUrl, 'https://albetnv.dev/cover.jpg');
    });

    test('reads the title from the page title when the header has no h1', () {
      expect(article.title, 'A log entry');
    });
  });

  test('a page without a body is refused', () {
    expect(
      () => adapter.parse(
        '<html><body><p>Nothing to read.</p></body></html>',
        uri: page,
      ),
      throwsA(isA<ArticleParseException>()),
    );
  });
}

String _text(List<ArticleInline> content) =>
    content.map((inline) => inline.text).join();
