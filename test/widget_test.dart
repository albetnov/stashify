// Smoke test for the Stashify home screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/main.dart';
import 'package:stashify/services/service_locator.dart';

import 'test_helper.dart';

void main() {
  setUp(() async {
    mockPathProvider();
  });

  testWidgets('Home screen shows stash input and an empty stash',
      (WidgetTester tester) async {
    // Real async zone: the driver's worker-isolate handshake never
    // resolves under testWidgets' FakeAsync. Pre-warmed here, reused by
    // the gate's own init when the app pumps below.
    await tester.runAsync(() => setupServicesAsync());
    await tester.pumpWidget(const StashifyApp());
    await tester.pumpAndSettle();

    expect(find.text('Stashify'), findsOneWidget);
    expect(find.text('Save for offline reading'), findsOneWidget);
    expect(
        find.widgetWithText(TextField, 'Paste article or feed URL'),
        findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Nothing stashed yet'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
  });
}
