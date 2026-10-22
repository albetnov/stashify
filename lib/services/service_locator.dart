import 'dart:io';

import 'package:fetch_forge/fetch_forge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_driver_forge/sqlite3_driver_forge.dart';
import 'package:sqlite_query_forge/sqlite_query_forge.dart';
import 'package:sqlite_schema_forge/sqlite_schema_forge.dart';

import 'package:stashify/data/stash_schema.dart';
import 'package:stashify/data/stash_store.dart';
import 'package:stashify/services/stash_service.dart';

final getIt = GetIt.instance;

/// Opens the app database, creating the file on first launch.
///
/// The connection lives on the driver's worker isolate: the UI thread
/// never touches SQLite directly.
Future<SqliteDriver> openAppDatabase({Directory? directory}) async {
  final dir = directory ?? await _appDbDir();
  final driver = SqliteDriver.file(p.join(dir.path, 'stashify.db'));
  await driver.connect();
  return driver;
}

/// Where the database file lives.
///
/// Tests run without platform plugins: plain unit tests have no binding at
/// all ([FlutterError] from the uninitialized `ServicesBinding`). Widget
/// tests mock path_provider (see `mockPathProvider` in test_helper.dart):
/// without the mock its channel hangs instead of throwing, which would
/// stall startup on the splash forever. The catches below are for exotic
/// platforms where the plugin is absent but the binding exists — anything
/// else failing still surfaces as a startup error.
Future<Directory> _appDbDir() async {
  try {
    return await getApplicationDocumentsDirectory();
  } on MissingPluginException {
    return Directory.systemTemp.createTemp('stashify.');
  } on FlutterError {
    return Directory.systemTemp.createTemp('stashify.');
  }
}

/// Registers the app's services. Safe to call more than once.
void setupServices() {
  // One query cache for the app: entry queries share it, so two rows for
  // the same link run one fetch. The scope never disposes it.
  if (!getIt.isRegistered<QueryClient>()) {
    getIt.registerSingleton<QueryClient>(
      QueryClient(),
      dispose: (client) => client.dispose(),
    );
  }

  // One client for the app: it keeps connections alive between writes and
  // the locator closes it.
  if (!getIt.isRegistered<http.Client>()) {
    getIt.registerSingleton<http.Client>(
      http.Client(),
      dispose: (client) => client.close(),
    );
  }

  // One database connection for the app, opened on first use. The locator
  // closes it.
  if (!getIt.isRegistered<SqliteDriver>()) {
    getIt.registerSingletonAsync<SqliteDriver>(
      openAppDatabase,
      dispose: (driver) => driver.disconnect(),
    );
  }

  if (!getIt.isRegistered<Forge>()) {
    getIt.registerSingletonAsync<Forge>(
      () async => Forge(await getIt.getAsync<SqliteDriver>()),
      dependsOn: [SqliteDriver],
    );
  }

  if (!getIt.isRegistered<StashStore>()) {
    getIt.registerSingletonAsync<StashStore>(
      () async => StashStore(await getIt.getAsync<Forge>()),
      dependsOn: [Forge],
    );
  }

  if (getIt.isRegistered<StashService>()) return;

  getIt.registerFactory<StashService>(
    () => StashService(
      client: getIt<http.Client>(),
      store: getIt.isRegistered<StashStore>() && getIt.isReadySync<StashStore>()
          ? getIt<StashStore>()
          : null,
    ),
  );
}

/// Async entry point for app startup.
///
/// Registers everything [setupServices] does, then opens the database,
/// migrates it, and preloads the library. Migration and preload still
/// land here; the connection already opens today.
///
/// [offline] skips persistence: the app runs memory-only for the session.
Future<void> setupServicesAsync({bool offline = false}) async {
  setupServices();
  if (!offline && !getIt.isReadySync<SqliteDriver>()) {
    // Opens the database file, creating it on first launch, then brings
    // the schema to v1. Skipped when another init already opened it:
    // migration runs once per process, and the driver never resolves
    // under testWidgets' FakeAsync, so a second touch would hang the
    // splash. Failures surface through the splash gate.
    final driver = await getIt.getAsync<SqliteDriver>();
    await SqliteSchemaForge.migrate(
      db: ForgeDatabaseExecutor(driver),
      targetSchema: stashSchema(),
      allowDestructive: false,
    );
    await getIt.getAsync<Forge>();
    await getIt.getAsync<StashStore>();
    // Preload lands here with the store.
  }
  // Yield so the splash paints at least one frame before home.
  await Future<void>.delayed(Duration.zero);
}
