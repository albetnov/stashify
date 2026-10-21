// Renders the screens to PNG so the design can be looked at, not guessed.
//
// This is NOT part of the test suite: it takes minutes, and the suite must
// stay fast. Run it on purpose when a screen's look needs checking:
//
//   flutter test tool/capture_test.dart
//
// The PNGs land in .impeccable/review/. Nothing is compared against them —
// this is a drawing board, not a regression gate.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/models/stash_item.dart';
import 'package:stashify/screens/feed_screen.dart';
import 'package:stashify/services/stash_service.dart';
import 'package:stashify/widgets/stash_row.dart';

const _fontDirs = [
  '/usr/share/fonts/truetype/roboto',
  '/usr/share/fonts/roboto',
];

/// Loads a font family if the machine has the file, so the captures show
/// type instead of the test font's boxes.
Future<void> _loadFont(String family) async {
  final home = Platform.environment['HOME'] ?? '';
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '$home/flutter';

  final candidates = [
    for (final dir in _fontDirs) '$dir/$family-Regular.ttf',
    '$home/.local/share/JetBrains/Toolbox/apps/android-studio/plugins/'
        'design-tools/resources/layoutlib/data/fonts/$family-Regular.ttf',
    '$flutterRoot/bin/cache/artifacts/material_fonts/$family-Regular.otf',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(
        Future.value(
          ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length),
        ),
      );
    await loader.load();
    return;
  }
}

Future<void> _loadFonts() async {
  await _loadFont('Roboto');
  await _loadFont('MaterialIcons');
}

StashItem _feed() => StashItem(
      id: 's1',
      url: 'https://example.com/feed.xml',
      title: 'Stashify Weekly',
      domain: 'example.com',
      savedAt: DateTime.now(),
      isFeed: true,
      entries: [
        StashEntry(
          title: 'Reading on the train',
          link: 'https://example.com/one',
          summary:
              'Why offline still wins when the connection does not, and what '
              'that means for the way we save things.',
          publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        StashEntry(
          title: 'The second entry, with a much longer headline that has to '
              'wrap and then some',
          link: 'https://example.com/two',
          summary: 'A shorter summary.',
          publishedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        StashEntry(
          title: 'Third entry',
          link: 'https://example.com/three',
          publishedAt: DateTime.now().subtract(const Duration(days: 12)),
        ),
      ],
    );

/// A feed screen backed by a seeded service, so the rows can read states.
FeedScreen _feedScreen() {
  final feed = _feed();
  final service = StashService();
  service.restore(feed, 0);
  return FeedScreen(feed: feed, service: service);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.impeccable/review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  final seed = const Color(0xFF0B6B4F);
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    ),
    home: child,
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('Feed screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: _feedScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stashify Weekly'), findsOneWidget);
    expect(find.text('3 entries · example.com'), findsOneWidget);

    await _capture(tester, 'feed_screen');
  });

  testWidgets('Feed screen, dark', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: _feedScreen(),
        ),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    await _capture(tester, 'feed_screen_dark');
  });

  testWidgets('Library row', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 260);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('capture'),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StashRow(
                  item: _feed(),
                  onOpen: () {},
                  onDelete: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _capture(tester, 'library_row');
  });
}
