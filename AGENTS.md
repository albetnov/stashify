# Working on Stashify

## Searching the filesystem

**Never search `/`.** A `find / -name ...` walks the whole machine, takes
minutes, and finds the same handful of paths every time.

Search the project first, then a known path:

- Project: `find . -name "*.ttf"`, `ls lib/`, `grep -rn ... lib/`.
- Flutter SDK: resolve it, do not guess —
  `dirname $(dirname $(readlink -f $(which flutter)))`. Its fonts live in
  `bin/cache/artifacts/material_fonts/` (`MaterialIcons-Regular.otf`).
- Fonts already known to exist on this machine:
  - Roboto: `~/.local/share/JetBrains/Toolbox/apps/android-studio/plugins/`
    `design-tools/resources/layoutlib/data/fonts/Roboto-Regular.ttf`
  - Material icons: the Flutter SDK path above.
- System fonts: `/usr/share/fonts/`.

Keep the username out of the files here: write paths as `$HOME/...` or as the
command that resolves them, never as the literal `/home/<you>/...`.

`tool/capture_test.dart` loads Roboto and MaterialIcons from those paths so
the captures show real type instead of the test font's boxes. It falls back
silently when they are missing.

## Verifying UI work

**Use widget tests. The human in the loop is the visual reviewer.**

The rules below are the default. The user can override any of them by
asking for it explicitly.

- **Widget tests are allowed** — and they are the way UI work is verified.
- **Capture-based tests are not.** They take minutes. `tool/capture_test.dart`
  renders the screens to PNG in `.impeccable/review/`; it lives outside
  `test/` on purpose, so `flutter test` never picks it up. Run it only when
  someone asks for captures:
  `flutter test tool/capture_test.dart`
- **No `flutter run`, no `flutter build`, no `adb`** for taking screenshots or
  driving the app. A sleeping device or a GPU surface that does not capture
  renders a blank image, and the loop is slow enough to hide changes behind
  it.
- **Run the whole suite at once**, not file by file:
  `flutter test` (it runs every test file in one go — do not loop over
  `flutter test test/<file>.dart`).
- `flutter analyze` must be clean too.
- **Integration tests only.** Cover behavior through widget tests that boot
  the real app (`tester.pumpWidget(const StashifyApp())`). Do not add plain
  unit tests for logic already reachable through a widget test; plain
  `test()`s are only for pure logic with no widget path (codecs, mappers).
- **No throwaway probe tests.** Never create temporary diagnostic tests to
  chase a failure: they are slow, and under `testWidgets` the FakeAsync
  zone makes them lie (timers and timeouts only fire on pump). Reproduce
  via the real suite and read the full `flutter test` log instead.
- **Real async needs `runAsync`.** `SqliteDriver.connect()` (worker-isolate
  handshake) never resolves under `testWidgets`' FakeAsync. Widget tests
  that boot the app pre-warm with
  `await tester.runAsync(() => setupServicesAsync())` before `pumpWidget`;
  driver behaviour itself is covered by plain `test()`s.

Verify a screen in `test/` instead:

- `tester.pumpWidget(...)` the screen with real content.
- Assert what the screen shows: `find.text(...)`, `find.widgetWithText(...)`.
- **Overflow is a test failure.** Flutter reports a `RenderFlex` overflow as
  an exception during layout, so a test that renders the screen at a small
  size and a large `textScaler` fails on its own when the layout breaks.
- Not everything that breaks is an exception. An app bar clips its title
  silently, so measure the geometry (`tester.getRect`) when a panel can
  swallow its content.
- Drive the interactions with `tester.tap(...)` and `tester.pumpAndSettle()`.

## The app

- `lib/services/` — the stash service: it fetches feeds over HTTP, parses
  them with `rss_dart`, and holds the stashed items in a signal. No Flutter
  imports live there.
- `lib/widgets/` — presentation. `StashShell` owns the write (a
  `fetch_forge` `Mutation`) and `StashInput` is the form inside it.
- `lib/screens/` — `HomeScreen` is the library, `FeedScreen` is the entries
  of a stashed feed.
- Writes go through a `fetch_forge` `Mutation`; reads are plain signals
  until the list becomes a query.
- Nothing is persisted yet: the stash lives in memory for this pass.
