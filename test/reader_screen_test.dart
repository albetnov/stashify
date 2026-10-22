// The reader: a stashed article rendered as a calm offline column.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/models/article.dart';
import 'package:stashify/models/stash_item.dart';
import 'package:stashify/screens/reader_screen.dart';

StashItem _item({String? cover}) => StashItem(
  id: 's1',
  url: 'https://albetnv.dev/blog/a-faster-validator/',
  title: 'From O(N²) to O(N): A Faster Validator',
  domain: 'albetnv.dev',
  savedAt: DateTime.now().subtract(const Duration(hours: 2)),
  readMinutes: 6,
  article: Article(
    title: 'From O(N²) to O(N): A Faster Validator',
    coverImageUrl: cover,
    blocks: const [
      ArticleHeading(level: 2, text: 'Summary'),
      ArticleParagraph([
        ArticleText('Validation used to scan the whole list twice. '),
        ArticleCodeSpan('Unique'),
        ArticleText(' makes one pass enough.'),
      ]),
      ArticleParagraph([
        ArticleText('Read the '),
        ArticleLink(text: 'original notes', href: 'https://albetnv.dev/x'),
        ArticleText(' for the full trace.'),
      ]),
      ArticleCode(
        code: 'final seen = <T>[];\nfor (final v in values) {}',
        language: 'dart',
      ),
      ArticleList(
        ordered: false,
        items: [
          ArticleListItem([ArticleText('Replaced quadratic checks')]),
          ArticleListItem([ArticleText('Kept the public API stable')]),
        ],
      ),
      ArticleList(
        ordered: true,
        items: [
          ArticleListItem([ArticleText('Measure first')]),
          ArticleListItem([ArticleText('Then simplify')]),
        ],
      ),
      ArticleQuote([
        ArticleParagraph([
          ArticleText('CPU efficiency matters more than theoretical purity.'),
        ]),
      ]),
      ArticleImage(url: 'https://albetnv.dev/body.png', alt: 'A chart'),
    ],
  ),
);

/// Text inside spans: [find.text] only sees whole [Text] widgets, so match
/// the plain text of [Text], [RichText] and [SelectableText] instead.
Finder _rich(String substring) => find.byWidgetPredicate((widget) {
  if (widget is Text) {
    final plain = widget.textSpan?.toPlainText() ?? widget.data ?? '';
    return plain.contains(substring);
  }
  if (widget is SelectableText) {
    final plain = widget.textSpan?.toPlainText() ?? widget.data ?? '';
    return plain.contains(substring);
  }
  return false;
});

Widget _screen(StashItem item) => MaterialApp(home: ReaderScreen(item: item));

void main() {
  testWidgets('The reader shows the title, meta, and every block kind', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_item()));

    expect(find.text('albetnv.dev'), findsOneWidget);
    expect(_rich('From O(N²) to O(N)'), findsWidgets);
    expect(_rich('2h ago'), findsOneWidget);
    expect(_rich('6 min read'), findsOneWidget);
    expect(_rich('available offline'), findsOneWidget);

    expect(_rich('Summary'), findsOneWidget);
    expect(_rich('Validation used to scan'), findsOneWidget);
    expect(_rich('Unique'), findsWidgets);
    expect(_rich('original notes'), findsOneWidget);
    expect(_rich('final seen'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    expect(_rich('Replaced quadratic checks'), findsOneWidget);
    expect(_rich('Measure first'), findsOneWidget);
    expect(_rich('1.'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pump();
    expect(_rich('CPU efficiency matters more'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pump();
    expect(_rich('A chart'), findsOneWidget);
  });

  testWidgets('A missing cover degrades instead of breaking the column', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(_item(cover: 'https://albetnv.dev/missing.jpg')),
    );
    await tester.pump();

    // Network images fail in tests; the column keeps its title and body.
    expect(_rich('Summary'), findsOneWidget);
    expect(_rich('final seen'), findsOneWidget);
  });

  testWidgets('Links explain they need a connection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_item()));

    await tester.tapOnText(find.textRange.ofSubstring('original notes'));
    await tester.pump();

    expect(find.textContaining('Links need a connection'), findsOneWidget);
  });

  testWidgets('The reader holds up on a small screen with large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0; // 360x640 logical
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _screen(_item()),
      ),
    );
    expect(_rich('Summary'), findsOneWidget);
    expect(_rich('original notes'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pump();

    expect(_rich('CPU efficiency matters more'), findsOneWidget);
  });

  testWidgets('The reader holds up at a large font scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _screen(_item()),
      ),
    );

    expect(find.text('albetnv.dev'), findsOneWidget);

    // The app bar keeps a single short domain line, so it never clips.
    final bar = tester.getRect(find.byType(AppBar));
    final title = tester.getRect(find.text('albetnv.dev'));
    expect(title.bottom, lessThanOrEqualTo(bar.bottom));
  });

  testWidgets('A long article does not overflow its column', (
    WidgetTester tester,
  ) async {
    final long = StashItem(
      id: 's2',
      url: 'https://albetnv.dev/blog/long/',
      title:
          'A headline long enough to wrap past the two lines a row would '
          'give it before it keeps going anyway',
      domain: 'albetnv.dev',
      savedAt: DateTime.now(),
      readMinutes: 12,
      article: const Article(
        title:
            'A headline long enough to wrap past the two lines a row would '
            'give it before it keeps going anyway',
        blocks: [
          ArticleParagraph([
            ArticleText(
              'A paragraph long enough to wrap many times over at any '
              'reasonable measure, carrying a link and code along the way '
              'without ever breaking the column it sits in, again and again.',
            ),
          ]),
          ArticleCode(
            code: 'void aVeryLongFunctionNameThatKeepsGoingAndGoingAndGoing() { return; }',
            language: 'dart',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_screen(long));

    expect(_rich('A headline long enough'), findsWidgets);
    expect(_rich('A paragraph long enough'), findsOneWidget);
  });
}
