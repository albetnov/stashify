// Regression test: stashing must not overflow on small screens / large text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/main.dart';
import 'package:stashify/services/service_locator.dart';
import 'package:stashify/services/stash_service.dart';

import 'fixtures/feed_fixture.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerFactory<StashService>(
      () => serviceServing(feedXml, delay: const Duration(milliseconds: 50)),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('Stash flow does not overflow on small screen, large text',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0; // 360x640 logical
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: StashifyApp(),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste article or feed URL'),
      'https://example.com/feed.xml',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Stash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.textContaining('Stashify Weekly'), findsOneWidget);
  });
}
