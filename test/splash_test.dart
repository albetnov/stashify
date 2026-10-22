// The launch gate: splash while services initialise, home after,
// and a way out when initialisation fails.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stashify/main.dart';
import 'package:stashify/services/service_locator.dart';

// ignore: unused_element_parameter
Future<void> _slowInit({bool offline = false}) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

Future<void> _failingInit() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  throw StateError('disk is gone');
}

void main() {
  setUp(() async {
    // Real registrations under the fake init timing: the injected
    // `initServices` only controls when init settles, not what it builds.
    setupServices();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('A slow start shows the splash, then home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const StashifyApp(initServices: _slowInit),
    );

    expect(find.text('Getting your library ready…'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Save for offline reading'), findsOneWidget);
    expect(find.text('Getting your library ready…'), findsNothing);
  });

  testWidgets('A failed start explains, retries, and recovers', (
    WidgetTester tester,
  ) async {
    var calls = 0;
    Future<void> flaky({bool offline = false}) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (calls == 1) throw StateError('disk is gone');
    }

    await tester.pumpWidget(StashifyApp(initServices: flaky));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t open your library'), findsOneWidget);
    expect(find.text('Save for offline reading'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Save for offline reading'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('Continuing offline skips the failing init and opens home', (
    WidgetTester tester,
  ) async {
    var sawOffline = false;

    await tester.pumpWidget(
      StashifyApp(
        initServices: ({bool offline = false}) async {
          if (offline) {
            sawOffline = true;
            return;
          }
          return _failingInit();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t open your library'), findsOneWidget);

    await tester.tap(find.text('Continue without saving'));
    await tester.pumpAndSettle();

    expect(find.text('Save for offline reading'), findsOneWidget);
    expect(sawOffline, isTrue);
  });

  testWidgets('The splash holds up at a large font scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0; // 360x640 logical
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Never completes: the splash is the whole subject, and no timer
    // is left pending at teardown.
    final gate = Completer<void>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: StashifyApp(
          initServices: ({bool offline = false}) => gate.future,
        ),
      ),
    );

    expect(find.text('Stashify'), findsOneWidget);
    expect(find.text('Getting your library ready…'), findsOneWidget);
  });
}
